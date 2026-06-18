-- @description TG: Sync Status
-- @version 0.1.0
-- @author Tryggvi Gylfason
-- @about
--   Show the status of all projects on the server.

local REAPER_SYNC = reaper.GetResourcePath() .. "/Data/reaper-sync/reaper-sync.sh"

local handle = io.popen('bash "' .. REAPER_SYNC .. '" status 2>&1')
local output = handle:read("*a")
handle:close()

reaper.ShowMessageBox(output, "Sync Status", 0)
