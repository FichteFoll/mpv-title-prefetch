--[[
title-prefetch

Version: 0.1.0
URL: https://github.com/FichteFoll/mpv-title-prefetch
License: MIT

Resolves the titles of playlist entries before they are played
and writes them into the native `playlist/N/title` property,
so that any OSC or playlist UI can show them.
Requires an mpv build in which `playlist/N/title` is writable (mpv PR #18599).

Options (script-opts/title-prefetch.conf or --script-opts=title-prefetch-<key>=<value>):
    range=5             entries before and after the current one;
                        negative = all, 0 = off
    resolve_remote=yes  resolve http(s):// and ytdl:// entries via yt-dlp
    resolve_local=yes   resolve local files via an mpv probe
    cache_size=100      maximum cached titles (FIFO); 0 = no cache, negative = unlimited
    concurrency=4       maximum simultaneous subprocesses
    timeout=30          seconds before a subprocess is aborted
    mpv_path=mpv        executable used for the local probe

Script messages:
    script-message-to title_prefetch resolve-more [count|all]
        resolve `count` more entries in each direction, or all of them

Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
SPDX-License-Identifier: MIT
--]]

local msg = require("mp.msg")
local options = require("mp.options")

---@class Options
---@field range integer
---@field resolve_remote boolean
---@field resolve_local boolean
---@field cache_size integer
---@field concurrency integer
---@field timeout number
---@field mpv_path string
local opts = {
    range = 5,
    resolve_remote = true,
    resolve_local = true,
    cache_size = 100,
    concurrency = 4,
    timeout = 30,
    mpv_path = "mpv",
}

---@param changed table<string, true>
local function on_update(changed)
    local keys = {}
    for key in pairs(changed) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    msg.debug("options updated: " .. table.concat(keys, ", "))
end

options.read_options(opts, "title-prefetch", on_update)

-- Unstable; for tests and debugging only.
mp.set_property_native("user-data/title-prefetch/idle", true)
