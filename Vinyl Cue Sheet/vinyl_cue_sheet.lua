--[[
  @description Vinyl Cue Sheet
  @version 1.0.0
  @author John Wright
  @link https://github.com/jg-wright/reaper-vinyl-cue-sheet
  @provides
    [main] vinyl_cue_sheet_settings.lua
    lib/config.lua
    lib/html.lua
    lib/pdf.lua
    lib/project.lua
    lib/regions.lua
    lib/render_format.lua
    lib/timecode.lua
  @about
    # Vinyl Cue Sheet

    Generates a vinyl cue-sheet from project regions/markers arranged in ruler
    lanes: one lane of regions defines the sides (e.g. !A, !B), another defines
    the track titles. Header details come from global settings; artist, album
    and audio format are read from the project. The cue sheet is written as HTML
    and converted to PDF when a converter (wkhtmltopdf or headless Chrome) is
    available on the system.

    Actions:
    - Vinyl Cue Sheet — generate the cue sheet for the current project.
    - Vinyl Cue Sheet: Settings — edit the persistent global settings.

    The settings editor uses ReaImGui when installed, otherwise a native dialog.
  @changelog
    Initial release.
--]]

local sep = package.config:sub(1, 1)
local script_dir = ({ reaper.get_action_context() })[2]:match("^(.*" .. sep .. ")")
package.path = script_dir .. "?.lua;" .. package.path

local config = require("lib.config")
local html = require("lib.html")
local pdf = require("lib.pdf")
local project = require("lib.project")
local regions = require("lib.regions")
local timecode = require("lib.timecode")

-- Directory of the current project file, or "" when the project is unsaved.
local function project_dir()
  local _, fn = reaper.EnumProjects(-1)
  if fn and fn ~= "" then
    return (fn:match("^(.*[/\\])")) or ""
  end
  return ""
end

local function output_dir(cfg)
  if cfg.output_dir ~= "" then return cfg.output_dir end
  local dir = project_dir()
  if dir ~= "" then return dir end
  return reaper.GetProjectPath("")
end

local function join(dir, name)
  if dir == "" then return name end
  if dir:sub(-1) == sep then return dir .. name end
  return dir .. sep .. name
end

local function write_file(path, contents)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write(contents)
  f:close()
  return path
end

local function main()
  local cfg = config.load()
  local meta = {
    project = project.get_name(),
    title = project.get_title(),
    author = project.get_author(),
    ext = project.get_render_ext(cfg),
  }

  local model = regions.build_model(cfg, meta)
  if #model.sides == 0 then
    reaper.ShowConsoleMsg(regions.diagnose_sides(cfg) .. "\n")
    reaper.MB(
      ("No side regions found in lane %q.\n\nEach side must be a region in the sides lane that is assigned at least one track in the Render dialog's Region Render Matrix. See the ReaScript console for a per-region breakdown.")
        :format(cfg.sides_lane),
      "Vinyl Cue Sheet", 0)
    return
  end

  local header = {
    title = meta.project .. " - Cue Sheet",
    pre_master = cfg.pre_master,
    engineer = cfg.engineer,
    phone = cfg.phone,
    email = cfg.email,
    client = cfg.client,
    artist = meta.author,
    album = meta.title,
    audio_format = project.get_audio_format(cfg),
  }

  local doc = html.from_model(model, header, function(seconds)
    return timecode.format(seconds, cfg.timecode_mode, true)
  end)
  local out_html = html.render(doc)

  local path = join(output_dir(cfg), header.title .. ".html")
  local written, err = write_file(path, out_html)
  if not written then
    reaper.MB("Could not write cue sheet:\n" .. tostring(err), "Vinyl Cue Sheet", 0)
    return
  end

  local pdf_path = path:gsub("%.html$", ".pdf")
  local ok, method, conv_err = pdf.convert(path, pdf_path, cfg)
  local final = ok and pdf_path or path

  if cfg.open_after_export == "true" then
    pdf.open(final)
  end

  local summary = {}
  if ok then
    summary[#summary + 1] = "Vinyl Cue Sheet (PDF via " .. method .. "):"
    summary[#summary + 1] = pdf_path
  else
    summary[#summary + 1] = "Vinyl Cue Sheet (HTML — no PDF conversion):"
    summary[#summary + 1] = path
    summary[#summary + 1] = "  " .. tostring(conv_err)
  end
  summary[#summary + 1] = ""
  summary[#summary + 1] = header.audio_format
  summary[#summary + 1] = ""
  for _, side in ipairs(model.sides) do
    summary[#summary + 1] = string.format("%s — %d track(s)", side.name, #side.tracks)
  end
  reaper.ShowConsoleMsg(table.concat(summary, "\n") .. "\n")
end

reaper.ClearConsole()
main()
