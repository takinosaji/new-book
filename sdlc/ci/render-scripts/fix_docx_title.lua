-- Quarto book docx: {{< include >}}'d sub-pages' title: frontmatter leaks into
-- the final Pandoc metadata, overriding book.title. Restore it here — this
-- Meta filter runs after all content is merged, so it wins.
function Meta(meta)
    if FORMAT ~= "docx" then return nil end
    local book = meta.book
    if book and book.title then
        meta.title = book.title
    end
    return meta
end
