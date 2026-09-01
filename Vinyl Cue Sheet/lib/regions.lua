-- Enumerate project regions/markers with their ruler-lane assignment.

local M = {}

-- Ruler lane display name for a lane number, or "" if unnamed/unavailable.
function M.lane_name(lane)
  local ok, name = reaper.GetSetProjectInfo_String(0, "RULER_LANE_NAME:" .. lane, "", false)
  if ok then return name end
  return ""
end

-- Number of ruler lanes in the project.
function M.lane_count()
  return math.floor(reaper.GetSetProjectInfo(0, "RULER_LANE_COUNT", 0, false) or 0)
end

-- Returns an ordered list of regions/markers:
--   { index, is_region, start_pos, end_pos, name, number, color, lane, lane_name }
-- Sorted by start position.
function M.enumerate()
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  local total = (num_markers or 0) + (num_regions or 0)

  local items = {}
  for i = 0, total - 1 do
    local retval, is_region, pos, rgn_end, name, number, color = reaper.EnumProjectMarkers3(0, i)
    if retval and retval > 0 then
      local lane = 0
      local rm = reaper.GetRegionOrMarker(0, i, "")
      if rm then
        lane = math.floor(reaper.GetRegionOrMarkerInfo_Value(0, rm, "I_LANENUMBER") or 0)
      end
      items[#items + 1] = {
        index = i,
        is_region = is_region,
        start_pos = pos,
        end_pos = rgn_end,
        name = name or "",
        number = number or 0,
        color = color or 0,
        lane = lane,
        lane_name = M.lane_name(lane),
      }
    end
  end

  table.sort(items, function(a, b)
    if a.start_pos == b.start_pos then
      return a.index < b.index
    end
    return a.start_pos < b.start_pos
  end)
  return items
end

-- Resolve a lane spec (a lane number like "1", or a lane name) to a lane number,
-- or nil if it cannot be resolved.
function M.resolve_lane_spec(spec)
  local n = tonumber(spec)
  if n then return math.floor(n) end
  for i = 0, M.lane_count() - 1 do
    if M.lane_name(i) == spec then return i end
  end
  return nil
end

local EPS = 1e-6

local function strip_prefix(name, prefix)
  if prefix ~= "" and name:sub(1, #prefix) == prefix then
    return name:sub(#prefix + 1)
  end
  return name
end

local function substitute(pattern, subs)
  return (pattern:gsub("%$(%w+)", function(key)
    return subs[key] or ("$" .. key)
  end))
end

-- Build the cue-sheet model: sides (from the sides lane) each containing the
-- tracks (from the tracks lane) that start within the side, with per-track times
-- relative to the side start and per-side track numbering.
--
--   meta = { project, title, author } (for render-filename substitution)
--   returns { sides = { { name, letter, raw_name, start_pos, end_pos,
--                         render_filename, tracks = { { number, title,
--                         start_rel, end_rel, length } } } },
--            sides_lane, tracks_lane }
function M.build_model(cfg, meta)
  meta = meta or {}
  local items = M.enumerate()
  local sides_lane = M.resolve_lane_spec(cfg.sides_lane)
  local tracks_lane = M.resolve_lane_spec(cfg.tracks_lane)

  local sides, track_items = {}, {}
  for _, rm in ipairs(items) do
    if sides_lane and rm.lane == sides_lane and rm.is_region then
      local letter = strip_prefix(rm.name, cfg.side_prefix)
      sides[#sides + 1] = {
        raw_name = rm.name,
        letter = letter,
        name = string.format(cfg.side_name_template, letter),
        start_pos = rm.start_pos,
        end_pos = rm.end_pos,
        tracks = {},
      }
    elseif tracks_lane and rm.lane == tracks_lane then
      track_items[#track_items + 1] = rm
    end
  end

  for _, side in ipairs(sides) do
    local members = {}
    for _, t in ipairs(track_items) do
      if t.start_pos >= side.start_pos - EPS and t.start_pos < side.end_pos - EPS then
        members[#members + 1] = t
      end
    end

    for i, t in ipairs(members) do
      local next_start = members[i + 1] and members[i + 1].start_pos or side.end_pos
      local track_end = (t.is_region and t.end_pos > t.start_pos + EPS) and t.end_pos or next_start
      side.tracks[i] = {
        number = i,
        title = t.name,
        start_rel = t.start_pos - side.start_pos,
        end_rel = track_end - side.start_pos,
        length = track_end - t.start_pos,
      }
    end

    side.render_filename = substitute(cfg.render_filename_pattern, {
      project = meta.project,
      title = meta.title,
      author = meta.author,
      side = side.letter,
      region = side.raw_name,
      ext = meta.ext,
    })
  end

  return { sides = sides, sides_lane = sides_lane, tracks_lane = tracks_lane }
end

return M
