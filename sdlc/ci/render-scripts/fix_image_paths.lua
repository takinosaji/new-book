-- In docx book mode Pandoc resolves image paths from the top-level chapter
-- directory, breaking paths written relative to their own sub-page location.
--
-- Strategy: for any .attachments/ image path, strip the optional prepended
-- chapter-dir component and then strip ALL leading "../" segments, leaving a
-- path relative to src/ (the CWD where Pandoc is invoked). Works for any depth.
--
-- Examples (chapter = annex/, CWD = src/):
--   depth-1: "annex/../.attachments/x"  → ".attachments/x"
--   depth-2: "annex/../../.attachments/x" → ".attachments/x"
--   depth-3: "annex/../../../.attachments/x" → ".attachments/x"
--   raw depth-2: "../../.attachments/x" → ".attachments/x"
function Image(img)
    if FORMAT ~= "docx" then return nil end
    local src = img.src

    -- Only touch paths that (after stripping) lead to .attachments/
    -- First strip an optional leading chapter-dir component (single dir, no dots)
    local s = src:match("^[^./][^/]*/(.+)") or src

    -- Strip all leading "../" segments
    while s:sub(1, 3) == "../" do
        s = s:sub(4)
    end

    -- Apply only if we land on a .attachments/ path and something changed
    if s ~= src and s:sub(1, 13) == ".attachments/" then
        img.src = s
        return img
    end

    return img
end
