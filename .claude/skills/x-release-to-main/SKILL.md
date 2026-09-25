Execute the following steps in order. Do not skip any step.

---

## Overview

This repository keeps two branches with different jobs:

- **`development`** — the real, granular commit history. Every change lands here.
- **`main`** — exactly ONE parentless commit, `Initial commit`, whose tree is a
  snapshot of `development`. Anyone cloning the template gets a clean history.

Publishing means: commit the working tree to `development`, push it, then rebuild
`main` as a fresh single snapshot commit and force-push it.

**The invariant that makes this safe:** `main^{tree}` always equals
`development^{tree}`. `main` holds no work that `development` lacks. If that ever
stops being true the branches have genuinely diverged, and rebuilding `main`
would silently discard whatever only `main` had.

## Pick the script for the platform

Two equivalent implementations live beside this file. Choose by the OS you are
running on, never by preference:

| Platform | Command |
| --- | --- |
| macOS / Linux | `.claude/skills/x-release-to-main/release-to-main.sh` |
| Windows | `pwsh -File .claude/skills/x-release-to-main/release-to-main.ps1` |

Both self-locate the repository root, so they work from any directory inside it.
Flags differ only in style: `-m/--message/--exclude/--dry-run/--yes` on the shell
script, `-Message/-Exclude/-DryRun/-Yes` in PowerShell.

## Always dry-run first, then run for real

```bash
.claude/skills/x-release-to-main/release-to-main.sh -m "<message>" --dry-run
.claude/skills/x-release-to-main/release-to-main.sh -m "<message>"
```

```powershell
pwsh -File .claude/skills/x-release-to-main/release-to-main.ps1 -Message "<message>" -DryRun
pwsh -File .claude/skills/x-release-to-main/release-to-main.ps1 -Message "<message>"
```

`--dry-run` runs every precondition and prints the plan without changing anything.
`--yes` skips the confirmation prompt — only pass it once the user has seen and
approved the path list.

**Never hand-run the git commands these scripts wrap**, and never substitute your
own sequence, even if it looks equivalent. They force-push `main`; a
half-remembered variant is how history gets lost. If a script refuses, fix the
cause it reports — do not work around it.

## Keeping paths out of the commit

The commit is `git add -A`, so untracked files are included by default. To leave
something out, pass `--exclude` (repeatable, git pathspec):

```bash
.claude/skills/x-release-to-main/release-to-main.sh -m "<message>" --exclude some/path
```

```powershell
pwsh -File .claude/skills/x-release-to-main/release-to-main.ps1 -Message "<message>" -Exclude some/path
```

Excluded paths stay in the working tree, uncommitted, and never reach `main`
(its tree is built from the `development` commit). The plan prints two lists —
`WILL BE COMMITTED` and `EXCLUDED` — so the user can confirm the split before
anything is pushed.

## Before invoking

1. Ask for the commit message if the user has not given one. It describes the work
   going onto `development`; `main`'s message is always `Initial commit`.
2. Run with `--dry-run` and **show the user the printed path list.**
3. Ask whether anything in it should be excluded, then re-run for real with any
   `--exclude` flags they asked for.

## Preconditions the scripts enforce

| Check | Why it exists |
| --- | --- |
| Non-empty message | `development` commits must be describable |
| `HEAD` is on `main` or `development` | Running from a feature branch would drag its work into the release |
| No merge conflicts or rebase in progress | Half-finished operations must not be published |
| Both branches exist locally | Nothing to reconcile otherwise |
| `main^{tree}` == `development^{tree}` | **The core invariant.** Hard stop — reconcile by hand |
| local `main` == `origin/main` | You must know exactly which commit you are replacing |
| local `development` not behind `origin/development` | Prevents pushing a stale history |
| Changes exist outside the excluded paths | Nothing to release otherwise |

## Postconditions the scripts verify

After a successful run all six are asserted, and the run fails loudly if any is off:

1. `main` has exactly 1 commit
2. that commit is parentless
3. `main^{tree}` == `development^{tree}`
4. `origin/main` points at the new snapshot
5. `origin/development` points at the new commit
6. nothing is left uncommitted outside the excluded paths

The run ends on `main`, matching the state you started in.

## If something goes wrong

The previous `origin/main` SHA is printed on every run, in the plan and in the
final summary. To undo the `main` rewrite:

```bash
git push --force origin <previous-sha>:main
```

`development` is only ever appended to, never rewritten, so it needs no recovery.

## Common mistakes

| Mistake | What happens |
| --- | --- |
| Committing to `main` first, then cherry-picking | The old manual flow. Cherry-picks can conflict and the invariant breaks. Commit to `development`; `main` is derived from it |
| Passing `--yes` before showing the path list | Untracked files get published unreviewed |
| Adding an unwanted path to `.gitignore` instead of `--exclude` | Changes the repo permanently to solve one release |
| "Fixing" a tree-divergence refusal with `git reset --hard` | Discards real work. Reconcile the two branches deliberately |
| Reproducing the git commands manually | Loses the precondition checks and the postcondition verification on a force-push |
