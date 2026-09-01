-- Offline test of render_format.decode.
-- Run with: lua "Vinyl Cue Sheet/test/render_format_spec.lua"

package.path = "Vinyl Cue Sheet/?.lua;" .. package.path

local rf = require("lib.render_format")

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64encode(bytes)
  local s = string.char(table.unpack(bytes))
  local out, bits, nbits = {}, 0, 0
  for i = 1, #s do
    bits = bits * 256 + s:byte(i)
    nbits = nbits + 8
    while nbits >= 6 do
      nbits = nbits - 6
      local scale = 2 ^ nbits
      out[#out + 1] = B64:sub(math.floor(bits / scale) + 1, math.floor(bits / scale) + 1)
      bits = bits % scale
    end
  end
  if nbits > 0 then
    out[#out + 1] = B64:sub(bits * (2 ^ (6 - nbits)) + 1, bits * (2 ^ (6 - nbits)) + 1)
  end
  while #out % 4 ~= 0 do out[#out + 1] = "=" end
  return table.concat(out)
end

local EVAW = { 0x65, 0x76, 0x61, 0x77 } -- "evaw"
local function wav(depth_byte)
  return b64encode({ EVAW[1], EVAW[2], EVAW[3], EVAW[4], depth_byte, 0x01, 0x00 })
end

-- Synthetic depth-byte cases: low bit is the float flag (float = depth+1).
local CASES = {
  { wav(0x08), "WAV", "wav", "8-bit PCM" },
  { wav(0x10), "WAV", "wav", "16-bit PCM" },
  { wav(0x18), "WAV", "wav", "24-bit PCM" },
  { wav(0x20), "WAV", "wav", "32-bit PCM" },
  { wav(0x21), "WAV", "wav", "32-bit float" },
  { wav(0x41), "WAV", "wav", "64-bit float" },
  -- Real REAPER output (regression):
  { "ZXZhdxgBAQ==", "WAV", "wav", "24-bit PCM" },
  { "ZXZhdyEBAQ==", "WAV", "wav", "32-bit float" },
}

for _, c in ipairs(CASES) do
  local b64, container, ext, detail = c[1], c[2], c[3], c[4]
  local d = rf.decode(b64)
  assert(d, "decode failed: " .. b64)
  assert(d.container == container, b64 .. " container=" .. tostring(d.container))
  assert(d.ext == ext, b64 .. " ext=" .. tostring(d.ext))
  assert(d.detail == detail, b64 .. " detail=" .. tostring(d.detail))
  print(string.format("%-16s -> %s / %s", b64, d.container, d.detail))
end

-- base64 precision regression: distinct final bytes must decode distinctly.
local hi = rf.decode(b64encode({ 0x65, 0x76, 0x61, 0x77, 0x18, 0x01, 0x01 })).raw_hex
local lo = rf.decode(b64encode({ 0x65, 0x76, 0x61, 0x77, 0x18, 0x01, 0x00 })).raw_hex
assert(hi:sub(-2) == "01" and lo:sub(-2) == "00", "final byte must survive decode")

-- Non-PCM container exposes container/ext but no bit-depth detail.
local mp3 = rf.decode(b64encode({ 0x6C, 0x33, 0x70, 0x6D, 0x00, 0x00, 0x00, 0x00 }))
assert(mp3 and mp3.container == "MP3" and mp3.ext == "mp3" and mp3.detail == nil, "mp3 case")
print("mp3 -> MP3 / <none>")

print("all render_format assertions passed")
