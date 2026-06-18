-- @description TG: Sync Push
-- @version 0.2.0
-- @author Tryggvi Gylfason
-- @about
--   Push the current Reaper project to the server and unlock it.

local HOME = os.getenv("HOME")
local REAPER_SYNC = reaper.GetResourcePath() .. "/Data/reaper-sync/reaper-sync.sh"

local function read_local_base()
  local f = io.open(HOME .. "/.config/reaper-sync/config", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content:match("LOCAL_BASE='(.-)'\n") or content:match("LOCAL_BASE=(.-)\n")
end

local function get_project_info()
  local _, projfn = reaper.EnumProjects(-1)
  if not projfn or projfn == "" then return nil, nil end
  local proj_dir = projfn:match("(.+)/[^/]+$")
  if not proj_dir then return nil, nil end
  return proj_dir:match("([^/]+)$"), proj_dir
end

local function run(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local output = handle:read("*a")
  handle:close()
  return output
end

local LOCAL_BASE = read_local_base()
if not LOCAL_BASE then
  reaper.ShowMessageBox(
    "reaper-sync is not configured.\n\nRun 'TG Sync Setup' first.",
    "Sync Push", 0)
  return
end

local project, proj_dir = get_project_info()
if not project then
  reaper.ShowMessageBox("No project is open.", "Sync Push", 0)
  return
end

local expected_dir = LOCAL_BASE .. "/" .. project
if proj_dir ~= expected_dir then
  reaper.ShowMessageBox(
    "This project is not in the sync directory.\n\n"
    .. "Project: " .. proj_dir .. "\n"
    .. "Expected: " .. expected_dir .. "\n\n"
    .. "Move it to the sync directory or re-run 'TG Sync Setup'.",
    "Sync Push", 0)
  return
end

reaper.Main_SaveProject(0, false)

local confirm = reaper.ShowMessageBox(
  "Push '" .. project .. "' to server and unlock?",
  "Sync Push", 4)
if confirm ~= 6 then return end

local output = run('bash "' .. REAPER_SYNC .. '" push "' .. project .. '"')
reaper.ShowMessageBox(output, "Sync Push", 0)
