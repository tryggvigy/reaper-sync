-- @description TG: Sync Pull
-- @version 0.2.0
-- @author Tryggvi Gylfason
-- @about
--   Pull a project from the server (locks it for editing).
--   Shows available projects, lets you pick one, pulls it, and opens it.

local HOME = os.getenv("HOME")
local REAPER_SYNC = reaper.GetResourcePath() .. "/Data/reaper-sync/reaper-sync.sh"

local function read_local_base()
  local f = io.open(HOME .. "/.config/reaper-sync/config", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content:match("LOCAL_BASE='(.-)'\n") or content:match("LOCAL_BASE=(.-)\n")
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
    "Sync Pull", 0)
  return
end

local status = run('bash "' .. REAPER_SYNC .. '" status')

reaper.ShowMessageBox(
  "Available projects:\n\n" .. status,
  "Sync Pull — Projects", 0)

local retval, input = reaper.GetUserInputs("Sync Pull", 1, "Project name:,extrawidth=200", "")
if not retval then return end

local project = input:match("^%s*(.-)%s*$")
if project == "" then return end

local confirm = reaper.ShowMessageBox(
  "Pull '" .. project .. "' from server?\n\nThis will lock it for editing.",
  "Sync Pull", 4)
if confirm ~= 6 then return end

local output = run('bash "' .. REAPER_SYNC .. '" pull "' .. project .. '"')
reaper.ShowMessageBox(output, "Sync Pull", 0)

-- Find the .rpp file (case-insensitive for .rpp/.RPP)
local proj_path = LOCAL_BASE .. "/" .. project
local handle = io.popen('find "' .. proj_path .. '" -maxdepth 1 -iname "*.rpp" -print -quit 2>/dev/null')
local rpp_file = handle:read("*l")
handle:close()

if rpp_file and rpp_file ~= "" then
  -- Check if this project is already open in a tab
  local already_open = false
  local i = 0
  while true do
    local proj, fn = reaper.EnumProjects(i)
    if not proj then break end
    if fn == rpp_file then
      already_open = true
      reaper.SelectProjectInstance(proj)
      break
    end
    i = i + 1
  end

  if already_open then
    reaper.Main_openProject("noprompt:" .. rpp_file)
    reaper.ShowMessageBox("Project reloaded from server.", "Sync Pull", 0)
  else
    reaper.Main_OnCommand(41929, 0) -- new project tab
    reaper.Main_openProject(rpp_file)
  end
end
