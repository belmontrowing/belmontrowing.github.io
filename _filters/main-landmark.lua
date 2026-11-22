-- Wraps each page's content in <div id="main-content" role="main">.
-- Quarto's "custom" page layout (used so sections can run edge to edge)
-- does not add a <main> element, which screen readers rely on.
-- You should never need to edit this file.
function Pandoc(doc)
  doc.blocks = pandoc.Blocks({
    pandoc.Div(doc.blocks, pandoc.Attr("main-content", {}, {role = "main"}))
  })
  return doc
end
