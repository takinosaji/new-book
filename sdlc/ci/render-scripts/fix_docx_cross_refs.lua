-- For docx book output, cross-file links such as
--   ../../application-architecture/ai-agentic-services.qmd#platform-core
-- are not resolved to internal bookmarks by pandoc because span anchors
-- ([]{#platform-core}) are not tracked across files when building the
-- merged book.
--
-- Strategy (docx only, two passes over the merged AST):
--
-- Pass 1 — collect the identifiers of all Span elements in the document.
--   Only span anchors need this treatment; heading anchors are resolved by
--   pandoc automatically and must NOT be touched.
--
-- Pass 2 — rewrite links of the form <path>.qmd#<fragment> to bare internal
--   refs (#fragment), but ONLY for fragments that are known span anchors.
--   Spans are NOT renamed — keeping original IDs avoids Word's 40-character
--   bookmark name limit (e.g. "ai-agentic-services--identity-and-access-
--   management" is 51 chars and gets silently SHA1-hashed by pandoc, breaking
--   the link).
--
-- HTML/website output is unaffected (the filter returns nil for non-docx formats).

function Pandoc(doc)
    if FORMAT ~= "docx" then return nil end

    -- Pass 1: collect all span anchor IDs present in the merged document
    local span_ids = {}
    doc:walk({
        Span = function(el)
            if el.identifier ~= '' then
                span_ids[el.identifier] = true
            end
        end
    })

    -- Pass 2: rewrite cross-file links targeting known span anchors to bare refs
    local changed = false
    local new_doc = doc:walk({
        Link = function(el)
            local fragment = el.target:match('%.qmd#(.+)$')
            if fragment and span_ids[fragment] then
                el.target = '#' .. fragment
                changed = true
                return el
            end
        end
    })

    return changed and new_doc or nil
end
