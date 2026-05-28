-- Depth-2 files included by depth-1 book chapters have their image paths
-- broken because Pandoc resolves them from the chapter directory.
-- "../../.attachments/image.png" included from a depth-2 file into a depth-1
-- chapter becomes unreachable (goes above project root).
--
-- Pandoc prepends the chapter directory before passing to the filter, so
-- img.src arrives as "chapter-dir/../../.attachments/..."
-- Stripping "chapter-dir/../../" leaves ".attachments/..." relative to CWD
-- (project root), which is where Pandoc is invoked from.
function Image(img)
    if FORMAT == "docx" then
        local src = img.src
        -- Case 1: Pandoc already prepended chapter dir → "chapter-dir/../../path"
        local stripped = src:gsub("^[^/]+/%.%.%/%.%.%/", "")
        if stripped ~= src then
            img.src = stripped
            return img
        end
        -- Case 2: Raw relative path still → "../../path"
        img.src = src:gsub("^%.%.%/%.%.%/", "../")
    end
    return img
end
