-- @description TG: Sync Healthcheck
-- @version 0.1.0
-- @author Tryggvi Gylfason
-- @about
--   Health check for reaper-sync. Verifies setup, CLI, and server connectivity.

local lines = {}
local all_ok = true

local function pass(label)
  lines[#lines + 1] = "[OK] " .. label
end

local function fail(label, detail)
  lines[#lines + 1] = "[FAIL] " .. label .. " — " .. detail
  all_ok = false
end

local function info(label, value)
  lines[#lines + 1] = "      " .. label .. ": " .. tostring(value)
end

local function sep(title)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "=== " .. title .. " ==="
end

local function run(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local output = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  return output
end

local HOME = os.getenv("HOME")
local resource = reaper.GetResourcePath()

-- 1. Config
sep("SETUP")

local config_path = HOME .. "/.config/reaper-sync/config"
local cf = io.open(config_path, "r")
if not cf then
  fail("Config file", "not found at " .. config_path .. " — run TG Sync Setup")
else
  local content = cf:read("*a")
  cf:close()
  pass("Config file exists")

  local server = content:match("SERVER='(.-)'\n") or content:match("SERVER=(.-)\n")
  local remote_base = content:match("REMOTE_BASE='(.-)'\n") or content:match("REMOTE_BASE=(.-)\n")
  local local_base = content:match("LOCAL_BASE='(.-)'\n") or content:match("LOCAL_BASE=(.-)\n")

  if server and server ~= "" then
    pass("SERVER configured")
    info("SERVER", server)
  else
    fail("SERVER", "not set in config")
  end

  if remote_base and remote_base ~= "" then
    pass("REMOTE_BASE configured")
    info("REMOTE_BASE", remote_base)
  else
    fail("REMOTE_BASE", "not set in config")
  end

  if local_base and local_base ~= "" then
    pass("LOCAL_BASE configured")
    info("LOCAL_BASE", local_base)
    local dir_exists = run('test -d "' .. local_base .. '" && echo yes || echo no')
    if dir_exists == "yes" then
      pass("Local projects directory exists")
    else
      fail("Local projects directory", local_base .. " does not exist")
    end
  else
    fail("LOCAL_BASE", "not set in config")
  end
end

-- 2. CLI
sep("CLI")

local cli_path = resource .. "/Data/reaper-sync/reaper-sync.sh"
local cli_file = io.open(cli_path, "r")
if cli_file then
  cli_file:close()
  pass("CLI script found")
  info("Path", cli_path)

  local test = run('bash "' .. cli_path .. '" help 2>&1')
  if test:match("Usage:") then
    pass("CLI runs successfully")
  else
    fail("CLI execution", test)
  end
else
  fail("CLI script", "not found at " .. cli_path)
end

-- 3. SSH / Server
sep("SERVER")

local ssh_path = run("which ssh")
if ssh_path ~= "" then
  pass("ssh available")
else
  fail("ssh", "not found in PATH")
end

local rsync_path = run("which rsync")
if rsync_path ~= "" then
  pass("rsync available")
else
  fail("rsync", "not found in PATH")
end

if cf then
  local content_again = io.open(config_path, "r")
  if content_again then
    local c = content_again:read("*a")
    content_again:close()
    local server = c:match("SERVER='(.-)'\n") or c:match("SERVER=(.-)\n")
    if server and server ~= "" then
      local ssh_test = run('ssh -o ConnectTimeout=5 "' .. server .. '" echo reaper-sync-ok 2>&1')
      if ssh_test:match("reaper%-sync%-ok") then
        pass("SSH connection to " .. server)

        local remote_base = c:match("REMOTE_BASE='(.-)'\n") or c:match("REMOTE_BASE=(.-)\n")
        if remote_base then
          local dir_test = run('ssh "' .. server .. '" "test -d \'' .. remote_base .. '\' && echo yes || echo no" 2>&1')
          if dir_test:match("yes") then
            pass("Remote projects directory exists")
          else
            fail("Remote projects directory", remote_base .. " not found on server")
          end
        end
      else
        fail("SSH connection", ssh_test)
      end
    end
  end
end

-- 4. Current project (for push readiness)
sep("CURRENT PROJECT")

local _, projfn = reaper.EnumProjects(-1)
if projfn and projfn ~= "" then
  pass("Project is open")
  local proj_dir = projfn:match("(.+)/[^/]+$")
  local proj_name = proj_dir and proj_dir:match("([^/]+)$") or "?"
  info("Name", proj_name)
  info("Path", proj_dir)

  local cf2 = io.open(config_path, "r")
  if cf2 then
    local c = cf2:read("*a")
    cf2:close()
    local local_base = c:match("LOCAL_BASE='(.-)'\n") or c:match("LOCAL_BASE=(.-)\n")
    if local_base and proj_dir then
      local expected = local_base .. "/" .. proj_name
      if proj_dir == expected then
        pass("Project is inside sync directory — push ready")
      else
        info("NOTE", "Project is outside sync directory (push would fail)")
        info("Expected", expected)
      end
    end
  end
else
  info("No project open", "(pull will still work)")
end

-- Summary
sep("SUMMARY")
if all_ok then
  lines[#lines + 1] = "All checks passed!"
else
  lines[#lines + 1] = "Some checks failed — see above."
end

local output = table.concat(lines, "\n")
reaper.ShowConsoleMsg(output .. "\n")
reaper.ShowMessageBox(output, "Sync Health Check", 0)
