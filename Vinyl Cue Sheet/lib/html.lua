-- @noindex
-- Pure HTML renderer for the vinyl cue sheet (no REAPER dependency).
-- Mirrors the example: bold-label header blocks, per-side heading + grey
-- filename + a bordered "# | Title | Start | End | Length" table.

local M = {}

local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }

local function esc(s)
  return (tostring(s or ""):gsub('[&<>"]', ESCAPES))
end

local CSS = [[
  body { font-family: Arial, Helvetica, sans-serif; color: #000; margin: 40px; }
  h1 { font-size: 30px; font-weight: bold; margin: 0 0 18px; }
  .block { margin-bottom: 16px; }
  .block p { margin: 2px 0; font-size: 13px; }
  h2 { font-size: 26px; font-weight: normal; margin: 30px 0 4px; }
  .filename { color: #8a8a8a; font-size: 12px; margin: 0 0 10px; }
  table { border-collapse: collapse; width: 100%; font-size: 13px; }
  th, td { border: 1px solid #cfcfcf; padding: 6px 10px; text-align: left; }
  th { background: #efefef; font-weight: normal; }
  th:first-child, td:first-child { width: 36px; }
]]

local function field_block(fields)
  local out = {}
  for _, f in ipairs(fields) do
    local value
    if f.link and f.value and f.value ~= "" then
      value = string.format('<a href="mailto:%s">%s</a>', esc(f.value), esc(f.value))
    else
      value = esc(f.value)
    end
    out[#out + 1] = string.format("    <p><strong>%s:</strong> %s</p>", esc(f.label), value)
  end
  return '  <div class="block">\n' .. table.concat(out, "\n") .. "\n  </div>"
end

local function side_block(side)
  local rows = { "      <tr><th>#</th><th>Title</th><th>Start</th><th>End</th><th>Length</th></tr>" }
  for _, t in ipairs(side.tracks) do
    rows[#rows + 1] = string.format(
      "      <tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
      esc(t.num), esc(t.title), esc(t.start), esc(t["end"]), esc(t.length))
  end
  return string.format(
    '  <h2>%s</h2>\n  <p class="filename">%s</p>\n  <table>\n%s\n  </table>',
    esc(side.name), esc(side.filename), table.concat(rows, "\n"))
end

-- Assemble a document table from the region model.
--   model       : output of regions.build_model
--   header      : { title, pre_master, engineer, phone, email,
--                   client, artist, album, audio_format }
--   format_time : function(seconds) -> string
function M.from_model(model, header, format_time)
  local sides = {}
  for _, s in ipairs(model.sides) do
    local tracks = {}
    for _, t in ipairs(s.tracks) do
      tracks[#tracks + 1] = {
        num = t.number,
        title = t.title,
        start = format_time(t.start_rel),
        ["end"] = format_time(t.end_rel),
        length = format_time(t.length),
      }
    end
    sides[#sides + 1] = { name = s.name, filename = s.render_filename, tracks = tracks }
  end

  return {
    title = header.title,
    global = {
      { label = "Pre-Master", value = header.pre_master },
      { label = "Engineer", value = header.engineer },
      { label = "Phone", value = header.phone },
      { label = "Email", value = header.email, link = true },
    },
    project = {
      { label = "Client", value = header.client },
      { label = "Artist", value = header.artist },
      { label = "Album", value = header.album },
      { label = "Audio Format", value = header.audio_format },
    },
    sides = sides,
  }
end

-- Render a document table to a complete HTML string.
function M.render(doc)
  local sides = {}
  for _, s in ipairs(doc.sides) do
    sides[#sides + 1] = side_block(s)
  end

  return table.concat({
    "<!DOCTYPE html>",
    '<html lang="en">',
    "<head>",
    '  <meta charset="utf-8">',
    "  <title>" .. esc(doc.title) .. "</title>",
    "  <style>" .. CSS .. "  </style>",
    "</head>",
    "<body>",
    "  <h1>" .. esc(doc.title) .. "</h1>",
    field_block(doc.global),
    field_block(doc.project),
    table.concat(sides, "\n"),
    "</body>",
    "</html>",
    "",
  }, "\n")
end

return M
