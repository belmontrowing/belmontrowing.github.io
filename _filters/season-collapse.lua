-- Two small jobs (see CLAUDE.md, "Season card" and "The one script"):
--
-- 1. COMPLETED SEASONS FOLD UP. A season card whose head holds a status note
--    ("The season has completed...") is rewritten as:
--      <div class="season-card is-complete">
--        head (the heading stays a real heading, outside the fold)
--        <details class="season-more">
--          <summary><span class="status-note">The season has completed...</span>
--                   <span class="season-toggle">Show / Hide season details</span></summary>
--          ...the season's sentence and tables...
--        </details>
--      </div>
--    Open seasons (a Register button in the head) are left alone. Nothing is
--    removed or re-worded; the note simply becomes the button that opens the card.
--
-- 2. LOADS scripts/site.js on every page, with a path that works from any folder.

local function has_class(el, c)
  return el.t == "Div" and el.classes:includes(c)
end

local function fold(card)
  local head = card.content[1]
  if not (head and has_class(head, "season-head")) then return nil end
  -- find the status note inside the head
  local note_i
  for i, b in ipairs(head.content) do
    if has_class(b, "status-note") then note_i = i end
  end
  if not note_i then return nil end               -- open season: leave it
  local note = head.content:remove(note_i)
  local label = pandoc.utils.blocks_to_inlines(note.content)

  local out = pandoc.Blocks{}
  if #head.content > 0 then out:insert(head) end  -- heading (if any) stays outside
  out:insert(pandoc.RawBlock("html", '<details class="season-more"><summary>'))
  out:insert(pandoc.Plain{ pandoc.Span(label, { class = "status-note" }) })
  -- a visible "Show / Hide season details" button (CSS shows the right one)
  out:insert(pandoc.RawBlock("html",
    '<span class="season-toggle"><span class="when-closed">Show season details</span>' ..
    '<span class="when-open">Hide season details</span></span>'))
  out:insert(pandoc.RawBlock("html", "</summary>"))
  for i = 2, #card.content do out:insert(card.content[i]) end
  out:insert(pandoc.RawBlock("html", "</details>"))
  card.content = out
  card.classes:insert("is-complete")
  return card
end

function Div(el)
  if el.classes:includes("season-card") then return fold(el) end
end

function Pandoc(doc)
  if quarto and quarto.doc.is_format("html") then
    local root = (quarto.project and quarto.project.offset) or "."
    doc.blocks:insert(pandoc.RawBlock("html",
      '<script src="' .. root .. '/scripts/site.js" defer></script>'))
  end
  return doc
end
