-- @description TG: Sync Setup
-- @version 0.1.0
-- @author Tryggvi Gylfason
-- @about
--   One-time setup for reaper-sync. Configures server connection
--   and local project path.
-- @provides
--   [data] ../client/reaper-sync.sh > reaper-sync/reaper-sync.sh

local HOME = os.getenv("HOME")
local CONFIG_DIR = HOME .. "/.config/reaper-sync"
local CONFIG_FILE = CONFIG_DIR .. "/config"

local function read_config_value(key)
  local f = io.open(CONFIG_FILE, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content:match(key .. "=(.-)\n")
end

local function guess_base_path()
  local _, projfn = reaper.EnumProjects(-1)
  if not projfn or projfn == "" then return nil end
  local proj_dir = projfn:match("(.+)/[^/]+$")
  if not proj_dir then return nil end
  return proj_dir:match("(.+)/[^/]+$")
end

-- Check for existing config
local existing_server = read_config_value("SERVER")
if existing_server then
  local ret = reaper.ShowMessageBox(
    "reaper-sync is already configured.\n\n"
    .. "Server: " .. (existing_server or "") .. "\n"
    .. "Remote path: " .. (read_config_value("REMOTE_BASE") or "") .. "\n"
    .. "Local path: " .. (read_config_value("LOCAL_BASE") or "") .. "\n\n"
    .. "Reconfigure?",
    "Sync Setup", 4)
  if ret ~= 6 then return end
end

-- Defaults
local def_server = existing_server or ""
local def_remote = read_config_value("REMOTE_BASE") or ""
local def_local = read_config_value("LOCAL_BASE") or guess_base_path() or (HOME .. "/ReaperProjects")

local retval, input = reaper.GetUserInputs(
  "Sync Setup", 3,
  "SSH server hostname:,Remote projects path:,Local projects folder:,extrawidth=300",
  def_server .. "," .. def_remote .. "," .. def_local)
if not retval then return end

local server, remote_base, local_base = input:match("^([^,]*),([^,]*),(.*)$")

server = server:match("^%s*(.-)%s*$")
remote_base = remote_base:match("^%s*(.-)%s*$")
local_base = local_base:match("^%s*(.-)%s*$")

if server == "" or remote_base == "" or local_base == "" then
  reaper.ShowMessageBox("All three fields are required.", "Sync Setup", 0)
  return
end

remote_base = remote_base:gsub("/$", "")
local_base = local_base:gsub("/$", "")

-- Write config
os.execute('mkdir -p "' .. CONFIG_DIR .. '"')

local f = io.open(CONFIG_FILE, "w")
if not f then
  reaper.ShowMessageBox(
    "Failed to write config file:\n" .. CONFIG_FILE,
    "Sync Setup", 0)
  return
end

f:write("SERVER=" .. server .. "\n")
f:write("REMOTE_BASE=" .. remote_base .. "\n")
f:write("LOCAL_BASE=" .. local_base .. "\n")
f:close()

reaper.ShowMessageBox(
  "Setup complete!\n\n"
  .. "Config: " .. CONFIG_FILE .. "\n"
  .. "Server: " .. server .. "\n"
  .. "Remote path: " .. remote_base .. "\n"
  .. "Local path: " .. local_base .. "\n\n"
  .. "You can now use Sync Push, Pull, and Status.",
  "Sync Setup", 0)
