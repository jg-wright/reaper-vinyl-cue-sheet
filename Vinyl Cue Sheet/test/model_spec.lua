-- Offline test of regions.build_model against a mock of the real project layout.
-- Not shipped; run with: lua "Vinyl Cue Sheet/test/model_spec.lua"

package.path = "Vinyl Cue Sheet/?.lua;" .. package.path

-- data: {lane, is_region, start, end, name}
local DATA = {
  { 2, false, 0,   0,   "!" },
  { 0, true,  2,   100, "Blue" },
  { 2, false, 2,   2,   "#Blue|PERFORMER=Borehead" },
  { 1, true,  2,   200, "!A" },
  { 0, true,  100, 200, "Heft" },
  { 2, false, 100, 100, "#Heft|PERFORMER=Borehead" },
  { 0, true,  200, 300, "Static" },
  { 2, false, 200, 200, "#Static|PERFORMER=Borehead" },
  { 1, true,  200, 400, "!B" },
  { 0, true,  300, 400, "Sour" },
  { 2, false, 300, 300, "#Sour|PERFORMER=Borehead" },
  { 2, false, 400, 400, "@4|PERFORMER=Borehead" },
}

reaper = {
  GetExtState = function() return "" end,
  format_timestr_pos = function(pos) return string.format("%.1fs", pos) end,
  CountProjectMarkers = function()
    local m, r = 0, 0
    for _, d in ipairs(DATA) do if d[2] then r = r + 1 else m = m + 1 end end
    return m + r, m, r
  end,
  EnumProjectMarkers3 = function(_, i)
    local d = DATA[i + 1]
    if not d then return 0 end
    return 1, d[2], d[3], d[4], d[5], i + 1, 0
  end,
  GetRegionOrMarker = function(_, i) return i + 1 end,
  GetRegionOrMarkerInfo_Value = function(_, rm) return DATA[rm][1] end,
  GetSetProjectInfo = function() return 0 end,
  GetSetProjectInfo_String = function() return false, "" end,
}

local config = require("lib.config")
local regions = require("lib.regions")

local cfg = config.load()
local model = regions.build_model(cfg, { project = "Borehead - 4", title = "4", author = "Borehead", ext = "wav" })

assert(model.sides_lane == 1 and model.tracks_lane == 0, "lane resolution")
assert(#model.sides == 2, "two sides")

local a = model.sides[1]
assert(a.name == "Side A" and a.raw_name == "!A", "side A name")
assert(a.render_filename == "Borehead_4_Side_A_MASTER.wav", "side A filename: " .. a.render_filename)
assert(#a.tracks == 2, "side A track count")
assert(a.tracks[1].title == "Blue" and a.tracks[1].number == 1, "A track1")
assert(a.tracks[1].start_rel == 0 and a.tracks[1].end_rel == 98 and a.tracks[1].length == 98, "A track1 times")
assert(a.tracks[2].title == "Heft" and a.tracks[2].start_rel == 98 and a.tracks[2].length == 100, "A track2 times")

local b = model.sides[2]
assert(b.name == "Side B" and #b.tracks == 2, "side B")
assert(b.tracks[1].title == "Static" and b.tracks[1].start_rel == 0, "B track1 resets to zero")
assert(b.tracks[2].title == "Sour" and b.tracks[2].number == 2, "B track2 numbering resets")

print("all model assertions passed")
for _, side in ipairs(model.sides) do
  print(string.format("%s (%s) -> %s", side.name, side.raw_name, side.render_filename))
  for _, t in ipairs(side.tracks) do
    print(string.format("  %d %-8s start=%g end=%g len=%g", t.number, t.title, t.start_rel, t.end_rel, t.length))
  end
end
