#!/usr/bin/env bash
set -euo pipefail

REMOTE="${RELEASE_REMOTE:-origin}"
MAIN_BRANCH="${RELEASE_MAIN_BRANCH:-main}"
DEV_BRANCH="${RELEASE_DEV_BRANCH:-development}"
SNAPSHOT_MESSAGE="${RELEASE_SNAPSHOT_MESSAGE:-Initial commit}"

message=""
assume_yes=false
dry_run=false
excludes=()

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

usage() {
    cat >&2 <<'USAGE'
Usage: release-to-main.sh -m "<commit message>" [--exclude <path>]... [--dry-run] [--yes]

Commits the working tree to development, pushes it, then rewrites main as a
single parentless snapshot commit of development's tree and force-pushes it.

  -m, --message   Commit message for the development commit (required)
      --exclude   Path left out of the commit and kept in the working tree.
                  Repeatable. Uses git pathspec, e.g. --exclude some/path
      --dry-run   Run every precondition and print the plan, change nothing
      --yes       Skip the interactive confirmation
  -h, --help      Show this help
USAGE
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m | --message)
            [[ $# -ge 2 ]] || die "--message requires a value"
            message="$2"
            shift 2
            ;;
        --exclude)
            [[ $# -ge 2 ]] || die "--exclude requires a path"
            excludes+=("$2")
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --yes)
            assume_yes=true
            shift
            ;;
        -h | --help) usage ;;
        *) die "unknown argument: $1" ;;
    esac
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
cd "$(git rev-parse --show-toplevel)"

[[ -n "${message//[[:space:]]/}" ]] || die "a non-empty commit message is required (-m)"

pathspec=(-- .)
if [[ ${#excludes[@]} -gt 0 ]]; then
    for ex in "${excludes[@]}"; do
        pathspec+=(":(exclude)$ex")
    done
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$current_branch" == "$MAIN_BRANCH" || "$current_branch" == "$DEV_BRANCH" ]] ||
    die "HEAD is on '$current_branch'; check out '$MAIN_BRANCH' or '$DEV_BRANCH' first"

[[ -z "$(git ls-files --unmerged)" ]] || die "unresolved merge conflicts in the index"
[[ ! -d "$(git rev-parse --git-path rebase-merge)" && ! -d "$(git rev-parse --git-path rebase-apply)" ]] ||
    die "a rebase is in progress"

git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH" || die "local branch '$MAIN_BRANCH' not found"
git show-ref --verify --quiet "refs/heads/$DEV_BRANCH" || die "local branch '$DEV_BRANCH' not found"

echo "Fetching $REMOTE ..."
git fetch --quiet "$REMOTE" "$MAIN_BRANCH" "$DEV_BRANCH"

main_tree="$(git rev-parse "$MAIN_BRANCH^{tree}")"
dev_tree="$(git rev-parse "$DEV_BRANCH^{tree}")"
[[ "$main_tree" == "$dev_tree" ]] || die "$(
    cat <<MSG
'$MAIN_BRANCH' and '$DEV_BRANCH' have different trees.
  $MAIN_BRANCH tree: $main_tree
  $DEV_BRANCH tree: $dev_tree
This script assumes '$MAIN_BRANCH' is a snapshot of '$DEV_BRANCH'. Reconcile
them by hand before releasing, or work committed only on one branch will be
silently discarded.
MSG
)"

local_main="$(git rev-parse "$MAIN_BRANCH")"
remote_main="$(git rev-parse "$REMOTE/$MAIN_BRANCH")"
[[ "$local_main" == "$remote_main" ]] ||
    die "local '$MAIN_BRANCH' ($local_main) differs from '$REMOTE/$MAIN_BRANCH' ($remote_main); fetch and reconcile first"

git merge-base --is-ancestor "$REMOTE/$DEV_BRANCH" "$DEV_BRANCH" ||
    die "local '$DEV_BRANCH' is behind '$REMOTE/$DEV_BRANCH'; pull or rebase first"

to_commit="$(git status --porcelain "${pathspec[@]}")"
[[ -n "$to_commit" ]] ||
    die "nothing to release: no changes outside the excluded paths"

echo
echo "================ RELEASE PLAN ================"
echo "repository:  $(pwd)"
echo "remote:      $REMOTE"
echo "message:     $message"
echo
echo "WILL BE COMMITTED to '$DEV_BRANCH':"
printf '%s\n' "$to_commit" | sed 's/^/    /'
if [[ ${#excludes[@]} -gt 0 ]]; then
    echo
    echo "EXCLUDED, left in the working tree:"
    for ex in "${excludes[@]}"; do
        excluded_status="$(git status --porcelain -- "$ex" || true)"
        if [[ -n "$excluded_status" ]]; then
            printf '%s\n' "$excluded_status" | sed 's/^/    /'
        else
            printf '    (%s matches nothing)\n' "$ex"
        fi
    done
fi
echo
echo "Then '$MAIN_BRANCH' becomes ONE parentless commit \"$SNAPSHOT_MESSAGE\""
echo "and is force-pushed, replacing $remote_main"
echo
echo "Recovery if this goes wrong:"
echo "    git push --force $REMOTE $remote_main:$MAIN_BRANCH"
echo "=============================================="
echo

if [[ "$dry_run" == true ]]; then
    echo "--dry-run: all preconditions passed, nothing was changed."
    exit 0
fi

echo "Everything under WILL BE COMMITTED goes in, untracked files included."
echo "Type 'release' to proceed:"
if [[ "$assume_yes" == false ]]; then
    read -r reply
    [[ "$reply" == "release" ]] || die "aborted by user"
else
    echo "(--yes given, skipping confirmation)"
fi

echo "==> switching to $DEV_BRANCH"
git switch "$DEV_BRANCH"

echo "==> committing to $DEV_BRANCH"
git add -A "${pathspec[@]}"
git commit -m "$message"
dev_commit="$(git rev-parse HEAD)"

echo "==> pushing $DEV_BRANCH"
git push "$REMOTE" "$DEV_BRANCH"

echo "==> rebuilding $MAIN_BRANCH as a single snapshot commit"
snapshot="$(git commit-tree "$DEV_BRANCH^{tree}" -m "$SNAPSHOT_MESSAGE")"
git branch -f "$MAIN_BRANCH" "$snapshot"

echo "==> force-pushing $MAIN_BRANCH"
git push --force-with-lease="$MAIN_BRANCH:$remote_main" "$REMOTE" "$MAIN_BRANCH"

echo "==> returning to $MAIN_BRANCH"
git switch "$MAIN_BRANCH"

echo "==> verifying postconditions"
failures=0
check() {
    if [[ "$2" == "$3" ]]; then
        printf '    OK   %s\n' "$1"
    else
        printf '    FAIL %s (expected %s, got %s)\n' "$1" "$3" "$2"
        failures=$((failures + 1))
    fi
}
check "$MAIN_BRANCH has exactly 1 commit" "$(git rev-list --count "$MAIN_BRANCH")" "1"
check "$MAIN_BRANCH commit is parentless" "$(git rev-list --parents -n1 "$MAIN_BRANCH" | wc -w | tr -d ' ')" "1"
check "$MAIN_BRANCH tree == $DEV_BRANCH tree" "$(git rev-parse "$MAIN_BRANCH^{tree}")" "$(git rev-parse "$DEV_BRANCH^{tree}")"
check "$REMOTE/$MAIN_BRANCH updated" "$(git rev-parse "$REMOTE/$MAIN_BRANCH")" "$snapshot"
check "$REMOTE/$DEV_BRANCH updated" "$(git rev-parse "$REMOTE/$DEV_BRANCH")" "$dev_commit"
check "nothing uncommitted outside excludes" "$(git status --porcelain "${pathspec[@]}" | wc -l | tr -d ' ')" "0"

echo
if [[ "$failures" -gt 0 ]]; then
    die "$failures postcondition(s) failed. Recover with: git push --force $REMOTE $remote_main:$MAIN_BRANCH"
fi
echo "Released."
echo "  $DEV_BRANCH: $dev_commit  $message"
echo "  $MAIN_BRANCH: $snapshot  $SNAPSHOT_MESSAGE"
echo "  previous $MAIN_BRANCH was $remote_main"
if [[ ${#excludes[@]} -gt 0 ]]; then
    echo "  excluded from the commit: ${excludes[*]}"
fi
