-- Exits with 0 if this mpv accepts a write to `playlist/1/title`, and with 3 otherwise.
-- Run with two playlist entries.

mp.register_event("file-loaded", function()
    if mp.set_property("playlist/1/title", "check") then
        mp.commandv("quit", 0)
    else
        mp.commandv("quit", 3)
    end
end)
