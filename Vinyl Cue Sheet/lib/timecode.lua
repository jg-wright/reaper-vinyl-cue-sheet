-- Timecode formatting via REAPER's project-aware formatter.

local M = {}

-- format_timestr_pos modeoverride values.
M.MODES = {
  ["-1"] = "project default",
  ["0"] = "time",
  ["1"] = "measures.beats + time",
  ["2"] = "measures.beats",
  ["3"] = "seconds",
  ["4"] = "samples",
  ["5"] = "h:m:s:f (frames)",
}

function M.mode_label(mode)
  return M.MODES[tostring(mode)] or "unknown"
end

-- Formats a position (seconds) using the given mode (string or number).
-- When trim_hours is true and the result is HH:MM:SS:FF with zero hours, the
-- leading hours field is dropped (e.g. "00:14:32:04" -> "14:32:04").
function M.format(pos, mode, trim_hours)
  local m = tonumber(mode) or -1
  local s = reaper.format_timestr_pos(pos or 0, "", m)
  if trim_hours then
    local h, rest = s:match("^(%d+):(%d+:%d+:%d+)$")
    if h and tonumber(h) == 0 then
      return rest
    end
  end
  return s
end

return M
