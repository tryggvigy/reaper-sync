-- @description TG: Sync Break Lock
-- @version 0.1.0
-- @author Tryggvi Gylfason
-- @about
--   Emergency unlock for a project locked by someone else.
--   Use when someone forgot to push/unlock and isn't available.

local REAPER_SYNC = reaper.GetResourcePath() .. "/Data/reaper-sync/reaper-sync.sh"

local function run(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local output = handle:read("*a")
  handle:close()
  return output
end

local status = run('bash "' .. REAPER_SYNC .. '" status')

reaper.ShowMessageBox(
  "Current projects:\n\n" .. status,
  "Sync Break Lock — Status", 0)

local retval, input = reaper.GetUserInputs("Sync Break Lock", 1, "Project to unlock:,extrawidth=200", "")
if not retval then return end

local project = input:match("^%s*(.-)%s*$")
if project == "" then return end

local confirm = reaper.ShowMessageBox(
  "WARNING: Only do this if you've confirmed with the person "
  .. "who locked it that it's safe.\n\n"
  .. "Break lock on '" .. project .. "'?",
  "Sync Break Lock", 4)
if confirm ~= 6 then return end

local second = reaper.ShowMessageBox(
  "Are you sure? Any unpushed changes by the lock holder will be at risk.",
  "Sync Break Lock", 4)
if second ~= 6 then return end

local output = run('bash "' .. REAPER_SYNC .. '" break-lock "' .. project .. '"')
reaper.ShowMessageBox(output, "Sync Break Lock", 0)
