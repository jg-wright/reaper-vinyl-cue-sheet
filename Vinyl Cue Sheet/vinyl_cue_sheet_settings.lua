--[[
  @noindex
  Vinyl Cue Sheet settings editor. Edits the persistent global configuration
  (stored via ExtState). Uses ReaImGui when available, otherwise falls back to a
  native multi-field dialog.
--]]

local sep = package.config:sub(1, 1)
local script_dir = ({ reaper.get_action_context() })[2]:match("^(.*" .. sep .. ")")
package.path = script_dir .. "?.lua;" .. package.path

local config = require("lib.config")

-- Field layout: { section = "..." } separators and { key, label, kind } fields.
local FIELDS = {
  { section = "Contact" },
  { "engineer", "Engineer", "text" },
  { "pre_master", "Pre-Master", "text" },
  { "phone", "Phone", "text" },
  { "email", "Email", "text" },
  { "client", "Client", "text" },
  { section = "Lanes" },
  { "sides_lane", "Sides lane (number or name)", "text" },
  { "tracks_lane", "Tracks lane (number or name)", "text" },
  { section = "Output" },
  { "timecode_mode", "Timecode", "timecode" },
  { "render_filename_pattern", "Render filename ($author $title $side $ext)", "text" },
  { "audio_format_override", "Audio format override", "text" },
  { "output_dir", "Output directory", "text" },
  { "pdf_converter", "PDF converter template ({in} {out})", "text" },
  { "open_after_export", "Open after export", "bool" },
}

-- Timecode option: { config value, label }.
local TIMECODES = {
  { "5", "Frames (h:m:s:f)" },
  { "0", "Time (h:m:s.ms)" },
  { "3", "Seconds" },
  { "2", "Measures.beats" },
}

local function keyed_fields()
  local out = {}
  for _, f in ipairs(FIELDS) do
    if f[1] then out[#out + 1] = f end
  end
  return out
end

local function save(values)
  for _, f in ipairs(keyed_fields()) do
    config.set(f[1], values[f[1]])
  end
end

--------------------------------------------------------------------------------
-- ReaImGui UI (raw reaper.ImGui_* API; avoids the shim's version gating)
--------------------------------------------------------------------------------

local function run_imgui()
  local ctx = reaper.ImGui_CreateContext("Vinyl Cue Sheet Settings")
  local values = config.load()
  local status = ""
  local cond_first = reaper.ImGui_Cond_FirstUseEver()

  local function timecode_combo(field)
    local current, labels = 0, {}
    for i, opt in ipairs(TIMECODES) do
      labels[#labels + 1] = opt[2]
      if opt[1] == values[field[1]] then current = i - 1 end
    end
    local changed, idx = reaper.ImGui_Combo(ctx, field[2], current, table.concat(labels, "\0") .. "\0")
    if changed then values[field[1]] = TIMECODES[idx + 1][1] end
  end

  local function frame()
    reaper.ImGui_SetNextWindowSize(ctx, 560, 640, cond_first)
    local visible, open = reaper.ImGui_Begin(ctx, "Vinyl Cue Sheet Settings", true)
    if visible then
      reaper.ImGui_PushItemWidth(ctx, -220)
      for _, f in ipairs(FIELDS) do
        if f.section then
          reaper.ImGui_Separator(ctx)
          reaper.ImGui_Text(ctx, f.section)
        elseif f[3] == "text" then
          local changed, nv = reaper.ImGui_InputText(ctx, f[2], values[f[1]] or "")
          if changed then values[f[1]] = nv end
        elseif f[3] == "bool" then
          local changed, nv = reaper.ImGui_Checkbox(ctx, f[2], values[f[1]] == "true")
          if changed then values[f[1]] = nv and "true" or "false" end
        elseif f[3] == "timecode" then
          timecode_combo(f)
        end
      end
      reaper.ImGui_PopItemWidth(ctx)

      reaper.ImGui_Separator(ctx)
      if reaper.ImGui_Button(ctx, "Save") then
        save(values)
        status = "Saved."
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Close") then open = false end
      if status ~= "" then
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, 0x66CC66FF, status)
      end
      reaper.ImGui_End(ctx)
    end
    if open then reaper.defer(frame) end
  end

  reaper.defer(frame)
end

--------------------------------------------------------------------------------
-- Fallback: native multi-field dialog
--------------------------------------------------------------------------------

local function split(s, delim)
  local out, start = {}, 1
  while true do
    local a, b = s:find(delim, start, true)
    if not a then
      out[#out + 1] = s:sub(start)
      break
    end
    out[#out + 1] = s:sub(start, a - 1)
    start = b + 1
  end
  return out
end

local function run_fallback()
  local values = config.load()
  local fields = keyed_fields()
  local labels, defaults = {}, {}
  for _, f in ipairs(fields) do
    labels[#labels + 1] = f[2]
    defaults[#defaults + 1] = tostring(values[f[1]] or "")
  end

  local ok, csv = reaper.GetUserInputs(
    "Vinyl Cue Sheet Settings",
    #fields,
    table.concat(labels, ",") .. ",extrawidth=260",
    table.concat(defaults, ","))
  if not ok then return end

  local parts = split(csv, ",")
  for i, f in ipairs(fields) do
    if parts[i] ~= nil then
      config.set(f[1], parts[i])
    end
  end
end

--------------------------------------------------------------------------------

if reaper.APIExists("ImGui_CreateContext") then
  run_imgui()
else
  run_fallback()
end
