-- Persistent global configuration via REAPER ExtState.

local M = {}

M.EXT_SECTION = "VinylCueSheet"

-- Field key -> default value. Strings only (ExtState stores strings).
M.DEFAULTS = {
  -- Global header block
  pre_master = "",
  engineer = "",
  phone = "",
  email = "",
  client = "",

  -- Region/marker classification. Lane may be a number ("0") or a lane name.
  sides_lane = "1",
  tracks_lane = "0",
  side_prefix = "!", -- optional convention: "!A"/"!B" -> "Side A"/"Side B"
  side_name_template = "Side %s",

  -- Formatting
  timecode_mode = "5", -- format_timestr_pos mode: 5 = h:m:s:f (frames)

  -- Render / output
  audio_format_override = "",
  render_filename_pattern = "$author_$title_Side_$side_MASTER.$ext",
  output_dir = "",
  open_after_export = "true",

  -- PDF converter command template ({in} and {out} placeholders)
  pdf_converter = "",
}

function M.get(key)
  local v = reaper.GetExtState(M.EXT_SECTION, key)
  if v == nil or v == "" then
    return M.DEFAULTS[key]
  end
  return v
end

function M.set(key, value)
  reaper.SetExtState(M.EXT_SECTION, key, tostring(value), true)
end

-- Returns a table with every configured value (defaults applied).
function M.load()
  local cfg = {}
  for key in pairs(M.DEFAULTS) do
    cfg[key] = M.get(key)
  end
  return cfg
end

return M
