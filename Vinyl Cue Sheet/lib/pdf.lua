-- @noindex
-- HTML -> PDF conversion by shelling out, with an open-in-default-app helper.
-- Command builders are pure and OS-parameterised so they can be tested offline;
-- the REAPER-specific bits (ExecProcess, file_exists, GetOS) are injectable.

local M = {}

local function is_windows(os_name)
  return os_name:find("Win") ~= nil
end

local function is_mac(os_name)
  return os_name:find("OSX") ~= nil or os_name:find("macOS") ~= nil
end

-- Single-quote a string for /bin/sh.
local function sq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function fill(template, map)
  return (template:gsub("{(%w+)}", function(k) return map[k] or ("{" .. k .. "}") end))
end

-- Wrap an inner command so a shell handles quoting/spaces.
function M.shell_wrap(inner, os_name)
  if is_windows(os_name) then
    return 'cmd.exe /C "' .. inner .. '"'
  end
  return "/bin/sh -c " .. sq(inner)
end

function M.wk_command(bin, html_path, pdf_path)
  return string.format('"%s" -q "%s" "%s"', bin, html_path, pdf_path)
end

function M.chrome_command(bin, html_path, pdf_path)
  return string.format(
    '"%s" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="%s" "%s"',
    bin, pdf_path, html_path)
end

function M.open_command(path, os_name)
  if is_windows(os_name) then return string.format('start "" "%s"', path) end
  if is_mac(os_name) then return string.format('open "%s"', path) end
  return string.format('xdg-open "%s"', path)
end

-- Ordered converter candidates for the OS.
local function candidates(os_name)
  if is_windows(os_name) then
    return {
      { kind = "wkhtmltopdf", cmd = M.wk_command, bins = {
        [[C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe]],
      } },
      { kind = "chrome", cmd = M.chrome_command, bins = {
        [[C:\Program Files\Google\Chrome\Application\chrome.exe]],
        [[C:\Program Files (x86)\Google\Chrome\Application\chrome.exe]],
        [[C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe]],
      } },
    }
  elseif is_mac(os_name) then
    return {
      { kind = "wkhtmltopdf", cmd = M.wk_command, bins = {
        "/opt/homebrew/bin/wkhtmltopdf", "/usr/local/bin/wkhtmltopdf",
      } },
      { kind = "chrome", cmd = M.chrome_command, bins = {
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
      } },
    }
  end
  return {
    { kind = "wkhtmltopdf", cmd = M.wk_command, bins = {
      "/usr/bin/wkhtmltopdf", "/usr/local/bin/wkhtmltopdf",
    } },
    { kind = "chrome", cmd = M.chrome_command, bins = {
      "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
    } },
  }
end

-- First available converter, or nil. exists(path) -> boolean.
function M.find_converter(os_name, exists)
  for _, c in ipairs(candidates(os_name)) do
    for _, bin in ipairs(c.bins) do
      if exists(bin) then
        return { kind = c.kind, bin = bin, cmd = c.cmd }
      end
    end
  end
  return nil
end

local function default_exists(p)
  return reaper.file_exists(p)
end

-- Runs a shell command and returns its exit code (and raw output).
local function default_exec(cmd)
  local ret = reaper.ExecProcess(cmd, 0)
  if not ret then return nil end
  return tonumber(ret:match("^%s*(%-?%d+)")) or -1, ret
end

-- Convert html_path -> pdf_path. Returns ok(boolean), method(string), err.
-- deps (optional): { os, exists, exec } for testing.
function M.convert(html_path, pdf_path, cfg, deps)
  deps = deps or {}
  local os_name = deps.os or reaper.GetOS()
  local exists = deps.exists or default_exists
  local exec = deps.exec or default_exec

  local inner, method
  if cfg and cfg.pdf_converter and cfg.pdf_converter ~= "" then
    inner = fill(cfg.pdf_converter, { ["in"] = html_path, out = pdf_path })
    method = "custom"
  else
    local conv = M.find_converter(os_name, exists)
    if not conv then return false, nil, "no PDF converter found" end
    inner = conv.cmd(conv.bin, html_path, pdf_path)
    method = conv.kind
  end

  local code, out = exec(M.shell_wrap(inner, os_name))
  if code == 0 and exists(pdf_path) then
    return true, method, nil
  end
  return false, method, string.format("%s exit=%s%s", method, tostring(code), out and ("\n" .. out) or "")
end

-- Open a file/URL in the default application (fire-and-forget).
function M.open(path, deps)
  deps = deps or {}
  local os_name = deps.os or reaper.GetOS()
  local exec = deps.exec or function(cmd) reaper.ExecProcess(cmd, -1) end
  exec(M.shell_wrap(M.open_command(path, os_name), os_name))
  return true
end

return M
