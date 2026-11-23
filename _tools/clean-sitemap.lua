-- Runs by itself after every `quarto render` (post-render in _quarto.yml).
-- You should never need to edit or run this file.
--
-- Quarto writes the search-engine sitemap (docs/sitemap.xml) with addresses such as
-- https://www.belmontrowing.org/about/index.html. Visitors, our links on other sites
-- and the <link rel="canonical"> tag on each page use the short form
-- https://www.belmontrowing.org/about/ instead, so this script rewrites every
-- ".../index.html" address in the sitemap to ".../" (keeping one entry per address).
-- Running it twice changes nothing.

local out_dir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or "docs"
local path = out_dir .. "/sitemap.xml"

local f = io.open(path, "r")
if not f then return end          -- no sitemap (e.g. no site-url): nothing to do
local xml = f:read("a")
f:close()

local order, newest = {}, {}
for block in xml:gmatch("<url>(.-)</url>") do
  local loc = block:match("<loc>%s*(.-)%s*</loc>")
  local lastmod = block:match("<lastmod>%s*(.-)%s*</lastmod>") or ""
  if loc then
    loc = loc:gsub("/index%.html$", "/")
    if newest[loc] == nil then
      order[#order + 1] = loc
      newest[loc] = lastmod
    elseif lastmod > newest[loc] then   -- dates are ISO text, so text order = time order
      newest[loc] = lastmod
    end
  end
end

local lines = {
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
}
for _, loc in ipairs(order) do
  lines[#lines + 1] = "  <url>"
  lines[#lines + 1] = "    <loc>" .. loc .. "</loc>"
  lines[#lines + 1] = "    <lastmod>" .. newest[loc] .. "</lastmod>"
  lines[#lines + 1] = "  </url>"
end
lines[#lines + 1] = "</urlset>"

f = assert(io.open(path, "w"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
