-- Offline test of the HTML renderer + a visual sample.
-- Run with: lua "Vinyl Cue Sheet/test/html_spec.lua"

package.path = "Vinyl Cue Sheet/?.lua;" .. package.path

local html = require("lib.html")

-- from_model: assemble + render a small model.
local model = {
  sides = {
    {
      name = "Side A",
      render_filename = "Borehead_4_Side_A_MASTER.wav",
      tracks = {
        { number = 1, title = "Blue", start_rel = 0, end_rel = 98, length = 98 },
        { number = 2, title = "Heft & <Co>", start_rel = 98, end_rel = 198, length = 100 },
      },
    },
  },
}
local header = {
  title = "Borehead - 4 - Cue Sheet",
  pre_master = "Aragon Towers", engineer = "JG Wright",
  phone = "+44 7454 696 367", email = "a@b.com",
  client = "Argonauta Records", artist = "Borehead", album = "4",
  audio_format = "WAV 48000Hz / 24-bit PCM",
}
local doc = html.from_model(model, header, function(s) return string.format("t%d", s) end)
local out = html.render(doc)

assert(out:find("<h1>Borehead %- 4 %- Cue Sheet</h1>"), "title")
assert(out:find("<strong>Pre%-Master:</strong> Aragon Towers"), "global field")
assert(out:find('<a href="mailto:a@b.com">a@b.com</a>'), "email link")
assert(out:find("<strong>Audio Format:</strong> WAV 48000Hz / 24%-bit PCM"), "audio format")
assert(out:find("<h2>Side A</h2>"), "side heading")
assert(out:find('class="filename">Borehead_4_Side_A_MASTER.wav'), "filename")
assert(out:find("<th>#</th><th>Title</th><th>Start</th><th>End</th><th>Length</th>"), "table header")
assert(out:find("<td>1</td><td>Blue</td><td>t0</td><td>t98</td><td>t98</td>"), "track row 1")
assert(out:find("Heft &amp; &lt;Co&gt;"), "html escaping")
print("all html assertions passed")

-- Visual sample mirroring the example PDF.
local sample = {
  title = "Borehead - 0004 - Cue Sheet",
  global = {
    { label = "Pre-Master", value = "Aragon Towers" },
    { label = "Engineer", value = "JG Wright" },
    { label = "Phone", value = "+44 7454 696 367" },
    { label = "Email", value = "johngeorgewright@gmail.com", link = true },
  },
  project = {
    { label = "Client", value = "Argonauta Records" },
    { label = "Artist", value = "Borehead" },
    { label = "Album", value = "0004" },
    { label = "Audio Format", value = "WAV 48000Hz / 24-bit PCM" },
  },
  sides = {
    { name = "Side A", filename = "Borehead_0004_Side_A_JGW_MASTER.wav", tracks = {
      { num = 1, title = "Blue", start = "00:00:00", ["end"] = "14:32:04", length = "14:32:04" },
      { num = 2, title = "Heft", start = "14:32:04", ["end"] = "21:57:36", length = "07:25:32" },
    } },
    { name = "Side B", filename = "Borehead_0004_Side_B_JGW_MASTER.wav", tracks = {
      { num = 1, title = "Static", start = "00:00:00", ["end"] = "09:03:00", length = "09:03:00" },
      { num = 2, title = "Sour", start = "09:03:00", ["end"] = "19:35:08", length = "10:32:08" },
    } },
  },
}
local f = assert(io.open("/tmp/vinyl_example.html", "w"))
f:write(html.render(sample))
f:close()
print("wrote /tmp/vinyl_example.html")
