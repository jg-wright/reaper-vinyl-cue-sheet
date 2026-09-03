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

-- True if the region with this displayed index number has at least one track
-- assigned in the project's Region Render Matrix.
function M.region_in_render_matrix(region_number)
  return reaper.EnumRegionRenderMatrix(0, region_number, 0) ~= nil
end

-- Diagnostic listing every region in the sides lane and whether it is assigned
-- in the Region Render Matrix. Shown when no sides are detected.
function M.diagnose_sides(cfg)
  local sides_lane = M.resolve_lane_spec(cfg.sides_lane)
  if not sides_lane then
    return ("Sides lane %q could not be resolved to a lane number."):format(cfg.sides_lane)
  end
  local lines = {}
  for _, rm in ipairs(M.enumerate()) do
    if rm.lane == sides_lane and rm.is_region then
      lines[#lines + 1] = string.format("  region #%d %q -> render matrix: %s",
        rm.number, rm.name, M.region_in_render_matrix(rm.number) and "assigned" or "NOT assigned")
    end
  end
  if #lines == 0 then
    return ("No regions at all were found in sides lane %q."):format(cfg.sides_lane)
  end
  return "Regions in the sides lane (a side must be assigned a track in the Region Render Matrix):\n"
    .. table.concat(lines, "\n")
end

local EPS = 1e-6

-- Per-side render filename, mirroring REAPER's Render dialog "File name" field
-- (RENDER_PATTERN). Region- and render-context wildcards are filled from the known
-- side and format (ResolveWildcards can't resolve those without a render in progress);
-- REAPER resolves the rest ($project/$author/$title/date/etc.) at the side start.
function M.render_filename(side, ext)
  local ok, pattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
  if not ok or pattern == "" then
    return side.name
  end
  pattern = pattern:gsub("%$regionnumber", tostring(side.number or ""))
    :gsub("%$region", side.name)
    :gsub("%$format", ext or "")
  local resolved = reaper.ResolveWildcards(0, side.start_pos, pattern, "")
  if ext and ext ~= "" then
    resolved = resolved .. "." .. ext
  end
  return resolved
end

-- Build the cue-sheet model: sides (from the sides lane) each containing the
-- tracks (from the tracks lane) that start within the side, with per-track times
-- relative to the side start and per-side track numbering.
--
--   meta = { ext } (render extension for the per-side render filename)
--   returns { sides = { { name, raw_name, number, start_pos, end_pos,
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
    if sides_lane and rm.lane == sides_lane and rm.is_region
        and M.region_in_render_matrix(rm.number) then
      sides[#sides + 1] = {
        raw_name = rm.name,
        name = rm.name,
        number = rm.number,
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

    side.render_filename = M.render_filename(side, meta.ext)
  end

  return { sides = sides, sides_lane = sides_lane, tracks_lane = tracks_lane }
end

return M
