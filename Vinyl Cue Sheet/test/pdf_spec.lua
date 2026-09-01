-- Offline test of the PDF module: pure command builders + a real conversion
-- through wkhtmltopdf (injected exec/exists, so no REAPER needed).
-- Run with: lua "Vinyl Cue Sheet/test/pdf_spec.lua"

package.path = "Vinyl Cue Sheet/?.lua;" .. package.path

local pdf = require("lib.pdf")

-- Pure command builders.
assert(pdf.shell_wrap("echo hi", "OSX64") == "/bin/sh -c 'echo hi'", "mac shell_wrap")
assert(pdf.shell_wrap("echo hi", "Win64") == 'cmd.exe /C "echo hi"', "win shell_wrap")
assert(pdf.wk_command("wk", "/a b.html", "/a b.pdf") == '"wk" -q "/a b.html" "/a b.pdf"', "wk_command")
assert(pdf.open_command("/a b.pdf", "OSX64") == 'open "/a b.pdf"', "open mac")
assert(pdf.open_command("/a b.pdf", "Win64") == 'start "" "/a b.pdf"', "open win")
assert(pdf.open_command("/a b.pdf", "Other") == 'xdg-open "/a b.pdf"', "open linux")

-- find_converter honours order and availability.
local function only(paths)
  local set = {}
  for _, p in ipairs(paths) do set[p] = true end
  return function(p) return set[p] == true end
end
local c = pdf.find_converter("OSX64", only({ "/usr/local/bin/wkhtmltopdf" }))
assert(c and c.kind == "wkhtmltopdf" and c.bin == "/usr/local/bin/wkhtmltopdf", "find wkhtmltopdf")
local c2 = pdf.find_converter("OSX64", only({ "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" }))
assert(c2 and c2.kind == "chrome", "find chrome fallback")
assert(pdf.find_converter("OSX64", only({})) == nil, "no converter")

print("pure builder assertions passed")

-- Real conversion via wkhtmltopdf, if present on PATH.
local function have(cmd)
  local h = io.popen("command -v " .. cmd .. " 2>/dev/null")
  local out = h:read("*a"); h:close()
  return out ~= nil and out:gsub("%s", "") ~= ""
end

if have("wkhtmltopdf") then
  local html_path = "/tmp/vinyl_pdf_spec.html"
  local pdf_path = "/tmp/vinyl_pdf_spec.pdf"
  os.remove(pdf_path)
  local f = assert(io.open(html_path, "w"))
  f:write("<!DOCTYPE html><html><body><h1>Cue Sheet test</h1></body></html>")
  f:close()

  local function exists(p)
    local fh = io.open(p, "rb")
    if fh then fh:close() return true end
    return false
  end
  local function exec(cmd)
    local ok, _, code = os.execute(cmd)
    return (ok == true) and 0 or (code or 1)
  end

  local cfg = { pdf_converter = 'wkhtmltopdf -q "{in}" "{out}"' }
  local ok, method, err = pdf.convert(html_path, pdf_path, cfg, { os = "OSX64", exists = exists, exec = exec })
  assert(ok, "convert failed: " .. tostring(err))
  assert(method == "custom", "method")
  assert(exists(pdf_path), "pdf not produced")
  print("real wkhtmltopdf conversion produced " .. pdf_path)
else
  print("wkhtmltopdf not on PATH; skipped real conversion")
end

print("all pdf assertions passed")
