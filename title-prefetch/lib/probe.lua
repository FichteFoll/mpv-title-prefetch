-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Runs inside the headless probe mpv that `lib/local.lua` spawns.
-- The plugin does not load this file itself.
-- Prints the loaded file's title as JSON to stdout, e.g. `{"title":"..."}` or `{}`, and quits.
-- A playlist file or archive yields no title.

-- A single-file script's directory is not on `package.path`.
local source = debug.getinfo(1, "S").source
local dir = source:match("^@(.*)[/\\]") or "."
package.path = dir .. "/?.lua;" .. package.path

local utils = require("mp.utils")
local media_title = require("media_title")

---@param title string?
local function report(title)
    io.stdout:write(utils.format_json({title = title}), "\n")
    io.stdout:flush()
    mp.commandv("quit", 0)
end

local redirected = false

mp.register_event("end-file", function(event)
    if event.reason ~= "redirect" then
        return
    end
    -- The entry is a playlist file or archive, which mpv replaces by its items,
    -- so it has no title of its own.
    redirected = true
    report(nil)
end)

mp.register_event("file-loaded", function()
    -- `quit` is asynchronous, so mpv may still load the first item after the redirect.
    if redirected then
        return
    end
    report(media_title.current())
end)
