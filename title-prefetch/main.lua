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
    cache_size=500      maximum cached titles (FIFO); 0 = no cache, negative = unlimited
    cache_dir=~~cache/title-prefetch
                        directory of the title cache; empty = no cache
    concurrency=4       maximum simultaneous subprocesses
    timeout=30          seconds before a subprocess is aborted
    mpv_path=mpv        executable used for the local probe

Script messages:
    script-message-to title_prefetch resolve-more [count|all]
        resolve `count` more entries in each direction, or all of them.
        `count` is a positive integer and defaults to `range` (5 if `range` is not positive).
        It also works when `range=0`.
        The extension lasts until the `range` option changes.

Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
SPDX-License-Identifier: MIT
--]]

local msg = require("mp.msg")
local options = require("mp.options")

local cache = require("lib.cache")
local local_files = require("lib.local")
-- `lib/probe.lua` runs as a single-file script and requires this module as `media_title`.
---@diagnostic disable-next-line: different-requires
local media_title = require("lib.media_title")
local queue = require("lib.queue")
local window = require("lib.window")
local ytdl = require("lib.ytdl")

---@class Options
---@field range integer
---@field resolve_remote boolean
---@field resolve_local boolean
---@field cache_size integer
---@field cache_dir string
---@field concurrency integer
---@field timeout number
---@field mpv_path string
local opts = {
    range = 5,
    resolve_remote = true,
    resolve_local = true,
    cache_size = 500,
    cache_dir = "~~cache/title-prefetch",
    concurrency = 4,
    timeout = 30,
    mpv_path = "mpv",
}

---@class Resolver
---@field enabled fun(): boolean
---@field matches fun(filename: string): boolean
---@field prepare fun(opts: Options): JobFactory called at most once per pass, on the first entry that needs it

---@type Resolver[]
local resolvers = {
    {
        enabled = function() return opts.resolve_local end,
        matches = local_files.matches,
        prepare = local_files.prepare,
    },
    {
        enabled = function() return opts.resolve_remote end,
        matches = ytdl.matches,
        prepare = ytdl.prepare,
    },
}

-- State is keyed by playlist entry filename.
---@type Cache
local titles
-- Filenames whose resolution failed or found no title; only playing the entry clears them.
---@type table<string, true>
local failed = {}
-- The `range` option, as extended by `resolve-more`; negative means all.
local effective_range = opts.range
-- Set when this mpv rejects writes to `playlist/N/title`.
local disabled = false
local pass_armed = false

---@type Queue
local q

-- Unstable; for tests and debugging only.
---@param idle boolean
local function publish_idle(idle)
    mp.set_property_native("user-data/title-prefetch/idle", idle)
end

---Write each title in `by_filename` into every untitled entry of `playlist` with that filename.
---This is the only place that writes titles.
---@param playlist table[] as read from the `playlist` property
---@param by_filename table<string, string>
local function write_titles(playlist, by_filename)
    if disabled then
        return
    end
    for i, entry in ipairs(playlist) do
        local title = by_filename[entry.filename]
        if title and not entry.title then
            local ok, err = mp.set_property("playlist/" .. (i - 1) .. "/title", title)
            -- "property not found" means the entry vanished since `playlist` was read.
            if not ok and err ~= "property not found" then
                msg.error("this script requires an mpv build with writable playlist/N/title"
                    .. " (mpv PR #18599); disabling it (" .. tostring(err) .. ")")
                disabled = true
                return
            end
        end
    end
end

---@param filename string
---@param factories table<Resolver, JobFactory> the factories of the current pass, extended as needed
---@return Job?
local function job_for(filename, factories)
    for _, resolver in ipairs(resolvers) do
        if resolver.enabled() and resolver.matches(filename) then
            local factory = factories[resolver]
            if not factory then
                factory = resolver.prepare(opts)
                factories[resolver] = factory
            end
            return factory(filename)
        end
    end
    return nil
end

local function run_pass()
    pass_armed = false
    if disabled then
        q:set_wanted({})
        publish_idle(not q:busy())
        return
    end

    local playlist = mp.get_property_native("playlist", {})
    local pos = mp.get_property_number("playlist-pos", -1) --[[@as integer]]
    -- Outside of idle mode, no position means that mpv has yet to pick the entry it plays,
    -- for example from `--playlist-start`, `--shuffle` or a watch-later resume.
    -- Resolving now could probe exactly that entry, so wait until the position is set.
    if pos < 0 and not mp.get_property_bool("idle-active", false) then
        q:set_wanted({})
        publish_idle(not q:busy())
        return
    end
    ---@type table<string, true>
    local seen = {}
    ---@type table<string, string>
    local cached_titles = {}
    ---@type string[]
    local pending = {}
    local cached_count = 0
    local indices = window.indices(#playlist, pos, effective_range)
    for _, i in ipairs(indices) do
        local entry = playlist[i + 1]
        local filename = entry.filename
        -- A failed entry is never cached in memory, so looking it up would only read the disk.
        if not entry.title and not seen[filename] and not failed[filename] then
            seen[filename] = true
            local cached = titles:get(filename)
            if cached then
                cached_titles[filename] = cached
                cached_count = cached_count + 1
            elseif not q:is_running(filename) then
                pending[#pending + 1] = filename
            end
        end
    end
    -- `write_titles` addresses entries by index into this pass's `playlist` read.
    -- Resolver work reads properties and files, during which other clients may reorder the playlist,
    -- so the writes come first.
    write_titles(playlist, cached_titles)
    ---@type Job[]
    local jobs = {}
    if not disabled then
        ---@type table<Resolver, JobFactory>
        local factories = {}
        for _, filename in ipairs(pending) do
            local job = job_for(filename, factories)
            if job then
                jobs[#jobs + 1] = job
            end
        end
    end
    if cached_count > 0 or #jobs > 0 then
        msg.debug(string.format(
            "pass: %d in window, %d cached, %d to resolve",
            #indices, cached_count, #jobs
        ))
    end
    q:set_wanted(jobs)
    publish_idle(not q:busy())
end

---Run a scheduling pass in the next event-loop turn, at most once per turn.
local function request_pass()
    if pass_armed then
        return
    end
    pass_armed = true
    publish_idle(false)
    mp.add_timeout(0, run_pass)
end

---@param filename string
---@param title string?
---@param retry boolean?
local function on_done(filename, title, retry)
    if title then
        titles:put(filename, title)
        write_titles(mp.get_property_native("playlist", {}), {[filename] = title})
    elseif not retry then
        failed[filename] = true
    end
    -- Also re-queues a retried entry, if it is still in the window.
    request_pass()
end

---@param changed table<string, true>
local function on_update(changed)
    local keys = {}
    for key in pairs(changed) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    msg.debug("options updated: " .. table.concat(keys, ", "))
    if changed.range then
        effective_range = opts.range
    end
    q:set_limits(opts.concurrency, opts.timeout)
    if changed.cache_dir then
        titles = cache.open(opts.cache_dir, opts.cache_size)
    else
        titles:set_limit(opts.cache_size)
    end
    request_pass()
end

---Refresh the cache with the title mpv determined for the file that is now playing.
local function on_file_loaded()
    local pos = mp.get_property_number("playlist-playing-pos", -1)
    local filename = mp.get_property("playlist/" .. pos .. "/filename")
    if not filename then
        return
    end
    local title = media_title.current()
    msg.debug("refreshing cache for " .. filename .. ": " .. tostring(title))
    if title then
        titles:put(filename, title)
        failed[filename] = nil
    else
        titles:remove(filename)
        failed[filename] = true
    end
    -- Untitled duplicates of the entry may now be written from the cache.
    request_pass()
end

---@param arg string?
local function on_resolve_more(arg)
    local count
    if arg == nil or arg == "" then
        count = opts.range > 0 and opts.range or 5
    elseif arg == "all" then
        count = -1
    elseif arg:match("^%d+$") and tonumber(arg) > 0 then
        count = tonumber(arg)
    else
        msg.warn("resolve-more: expected a positive integer or `all`, got: " .. arg)
        return
    end
    if effective_range < 0 then
        return
    end
    effective_range = count < 0 and -1 or effective_range + count
    msg.debug("effective range: " .. effective_range)
    request_pass()
end

options.read_options(opts, "title-prefetch", on_update)
q = queue.new{concurrency = opts.concurrency, timeout = opts.timeout, on_done = on_done}
titles = cache.open(opts.cache_dir, opts.cache_size)
effective_range = opts.range

publish_idle(true)
mp.observe_property("playlist", "native", request_pass)
-- Leaving or entering idle mode decides whether a pass at `playlist-pos == -1` is deferred.
mp.observe_property("idle-active", "bool", request_pass)
mp.observe_property("playlist-pos", "number", request_pass)
-- Remote entries are only resolved while `ytdl` is enabled.
mp.observe_property("ytdl", "bool", request_pass)
mp.register_event("file-loaded", on_file_loaded)
mp.register_script_message("resolve-more", on_resolve_more)
