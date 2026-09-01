-- Project metadata and render information.

local render_format = require("lib.render_format")

local M = {}

local function project_info_string(key)
  local ok, value = reaper.GetSetProjectInfo_String(0, key, "", false)
  if ok and value ~= "" then
    return value
  end
  return nil
end

local function resolve_wildcard(token)
  local value = reaper.ResolveWildcards(0, -1, token, "")
  if value and value ~= "" and value ~= token then
    return value
  end
  return nil
end

-- Project file name without directory or extension ($project).
function M.get_name()
  local value = resolve_wildcard("$project")
  if value then return value end
  local _, name = reaper.GetProjectName(0)
  name = name or ""
  return (name:gsub("%.[Rr][Pp][Pp]$", ""))
end

function M.get_author()
  return project_info_string("PROJECT_AUTHOR") or resolve_wildcard("$author") or ""
end

function M.get_title()
  return project_info_string("PROJECT_TITLE") or resolve_wildcard("$title") or ""
end

-- Sample rate used for rendering (falls back to the project sample rate).
function M.get_render_srate()
  local srate = reaper.GetSetProjectInfo(0, "RENDER_SRATE", 0, false)
  if srate and srate > 0 then
    return math.floor(srate)
  end
  local proj_srate = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  return math.floor(proj_srate or 0)
end

function M.get_render_channels()
  return math.floor(reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 0, false) or 0)
end

-- Human-readable audio format, e.g. "WAV 48000Hz / 24-bit PCM".
-- Uses the configured override when auto-detection is incomplete.
function M.get_audio_format(cfg)
  if cfg and cfg.audio_format_override and cfg.audio_format_override ~= "" then
    return cfg.audio_format_override
  end

  local ok, render_cfg = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
  local decoded = ok and render_format.decode(render_cfg) or nil
  local srate = M.get_render_srate()

  local container = decoded and decoded.container or "?"
  local parts = { container }
  if srate > 0 then
    parts[#parts + 1] = srate .. "Hz"
  end
  if decoded and decoded.detail then
    parts[#parts + 1] = "/ " .. decoded.detail
  end
  return table.concat(parts, " ")
end

-- File extension matching the render container (e.g. "wav", "mp3"). Falls back to
-- the audio-format override's first token, then "wav".
function M.get_render_ext(cfg)
  if cfg and cfg.audio_format_override and cfg.audio_format_override ~= "" then
    local first = cfg.audio_format_override:match("^(%S+)")
    if first then return first:lower() end
  end
  local ok, render_cfg = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
  local decoded = ok and render_format.decode(render_cfg) or nil
  return decoded and decoded.ext or "wav"
end

-- Human-readable dump of the raw render config, for verifying the decoder.
function M.render_format_debug()
  local ok, render_cfg = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
  if not ok or render_cfg == "" then
    return "RENDER_FORMAT: <none>"
  end
  local d = render_format.decode(render_cfg)
  if not d then
    return "RENDER_FORMAT b64=" .. render_cfg .. " (undecodable)"
  end
  return string.format(
    "RENDER_FORMAT b64=%s\n  hex=%s\n  container=%s ext=%s detail=%s",
    d.b64, d.raw_hex, d.container, d.ext, d.detail or "<none>")
end

return M
