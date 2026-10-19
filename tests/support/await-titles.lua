-- Script for nested mpv instances that the tests start.
-- Waits until every entry from index 1 on has a title,
-- writes the marker `$TP_TMP/await-titles.done` and kills its own mpv.
-- SIGKILL leaves no `shutdown` handler a chance to write the title cache,
-- so the cache must have been written already.
-- Index 0 is the playing entry, which the plugin leaves to mpv.

local utils = require("mp.utils")

local marker = utils.join_path(os.getenv("TP_TMP") --[[@as string]], "await-titles.done")

---@return boolean
local function all_titled()
    local count = mp.get_property_number("playlist-count", 0) --[[@as integer]]
    if count < 2 then
        return false
    end
    for i = 1, count - 1 do
        local title = mp.get_property("playlist/" .. i .. "/title")
        if not title or title == "" then
            return false
        end
    end
    return true
end

local deadline = mp.get_time() + 20
local timer
timer = mp.add_periodic_timer(0.05, function()
    if all_titled() then
        timer:kill()
        local f = assert(io.open(marker, "w"))
        f:close()
        os.execute("kill -9 " .. utils.getpid())
    elseif mp.get_time() > deadline then
        timer:kill()
        mp.commandv("quit", 1)
    end
end)
