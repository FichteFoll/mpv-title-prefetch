-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Runs inside the headless probe mpv that `lib/local.lua` spawns.
-- The plugin does not load this file itself.
-- Prints the loaded file's title as JSON to stdout, e.g. `{"title":"..."}` or `{}`, and quits.

-- A single-file script's directory is not on `package.path`.
local source = debug.getinfo(1, "S").source
local dir = source:match("^@(.*)[/\\]") or "."
package.path = dir .. "/?.lua;" .. package.path

local utils = require("mp.utils")
local media_title = require("media_title")

mp.register_event("file-loaded", function()
    io.stdout:write(utils.format_json({title = media_title.current()}), "\n")
    io.stdout:flush()
    mp.commandv("quit", 0)
end)
