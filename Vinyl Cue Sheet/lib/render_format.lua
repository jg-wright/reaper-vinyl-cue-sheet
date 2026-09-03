-- @noindex
-- Decodes the base64 RENDER_FORMAT sink configuration.
--
-- The config begins with a 4-byte fourcc (the container name stored
-- little-endian, e.g. "evaw" for WAV). For WAV/AIFF the bit depth follows at
-- offset 4. Other containers expose only the container/extension.

local M = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_decode(data)
  if not data or data == "" then return "" end
  data = data:gsub("[^" .. B64 .. "=]", "")
  local lookup = {}
  for i = 1, #B64 do lookup[B64:sub(i, i)] = i - 1 end

  local bytes = {}
  local bits, nbits = 0, 0
  for i = 1, #data do
    local c = data:sub(i, i)
    if c == "=" then break end
    bits = bits * 64 + lookup[c]
    nbits = nbits + 6
    if nbits >= 8 then
      nbits = nbits - 8
      local scale = 2 ^ nbits
      bytes[#bytes + 1] = string.char(math.floor(bits / scale))
      bits = bits % scale -- drop consumed bits to keep the accumulator small
    end
  end
  return table.concat(bytes)
end

local CONTAINERS = {
  wave = "WAV",
  aiff = "AIFF",
  caff = "CAF",
  flac = "FLAC",
  mp3l = "MP3",
  oggv = "OGG",
}

local EXTENSIONS = {
  WAV = "wav",
  AIFF = "aiff",
  CAF = "caf",
  FLAC = "flac",
  MP3 = "mp3",
  OGG = "ogg",
}

local function to_hex(s)
  local t = {}
  for i = 1, #s do t[i] = string.format("%02X", s:byte(i)) end
  return table.concat(t, " ")
end

-- Returns a table describing the render format, or nil if undecodable:
--   { container, ext, fourcc, bits, sample_fmt, detail, raw_hex, b64 }
-- `detail` (e.g. "24-bit PCM") is only set when confidently decoded.
--
-- WAV/AIFF layout: 4-byte fourcc ("evaw") followed by a bit-depth byte at
-- offset 4. That byte's low bit is a float flag (float encodes as depth+1), so
-- 0x18 = 24-bit PCM and 0x21 = 32-bit float (verified against REAPER output).
function M.decode(render_cfg_b64)
  local raw = base64_decode(render_cfg_b64)
  if #raw < 4 then return nil end

  local fourcc = raw:sub(1, 4)
  local name = fourcc:reverse():lower()
  local container = CONTAINERS[name] or name:upper()

  local info = {
    container = container,
    ext = EXTENSIONS[container] or name,
    fourcc = fourcc,
    b64 = render_cfg_b64,
    raw_hex = to_hex(raw),
  }

  if (container == "WAV" or container == "AIFF") and #raw >= 5 then
    local b = raw:byte(5)
    local is_float = (b % 2 == 1)
    local depth = is_float and (b - 1) or b
    if depth == 8 or depth == 16 or depth == 24 or depth == 32 or depth == 64 then
      info.bits = depth
      info.sample_fmt = is_float and "float" or "PCM"
      info.detail = string.format("%d-bit %s", depth, info.sample_fmt)
    end
  end

  return info
end

return M
