-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Resolves titles of remote URLs with yt-dlp,
-- found and invoked the way mpv's ytdl_hook does it.

local msg = require("mp.msg")
local utils = require("mp.utils")

local ytdl = {}

local DEFAULT_PATHS = {"yt-dlp", "yt-dlp_x86", "youtube-dl"}

-- Candidates whose run failed because they could not be started.
---@type table<string, true>
local missing = {}

-- Whether the absence of every candidate has been warned about since one was last found.
local warned_none = false

---@return boolean
local function is_windows()
    return mp.get_property_native("platform") == "windows"
end

---Read `ytdl_path` from ytdl_hook's config file,
---with the same line rules as `mp.options`.
---@return string?
local function ytdl_path_from_conf()
    local conf = mp.find_config_file("script-opts/ytdl_hook.conf")
    local f = conf and io.open(conf, "r")
    if not f then
        return nil
    end
    local value
    for line in f:lines() do
        line = line:gsub("\r$", "")
        if line:sub(1, 1) ~= "#" then
            local v = line:match("^ytdl_path=(.*)$")
            if v then
                value = v
            end
        end
    end
    f:close()
    return value
end

---ytdl_hook's `ytdl_path` option, read anew on each call,
---so that changes to `script-opts` apply.
---`options.read_options` is not used for this,
---because it warns about every other ytdl_hook option the user has set.
---@return string
local function ytdl_path_option()
    local script_opts = mp.get_property_native("options/script-opts", {})
    return script_opts["ytdl_hook-ytdl_path"] or ytdl_path_from_conf() or ""
end

---@return string[]
local function candidates()
    local separator = is_windows() and ";" or ":"
    ---@type string[]
    local paths = {}
    for path in ytdl_path_option():gmatch("[^" .. separator .. "]+") do
        paths[#paths + 1] = path
    end
    if #paths == 0 then
        return DEFAULT_PATHS
    end
    return paths
end

---@return string? executable nil when every candidate is known to be missing
local function executable()
    -- Read natively: `mp.get_property` formats `user-data` values as JSON, so strings come quoted.
    local hook_path = mp.get_property_native("user-data/mpv/ytdl/path", "")
    if type(hook_path) == "string" and hook_path ~= "" and not missing[hook_path] then
        return hook_path
    end

    -- Like ytdl_hook: per candidate, prefer a copy in the config directories over the bare name.
    for _, path in ipairs(candidates()) do
        local suffix = (is_windows() and not path:lower():match("%.exe$")) and ".exe" or ""
        local exe = mp.find_config_file(path .. suffix) or path
        if not missing[exe] then
            return exe
        end
    end
    return nil
end

---@param exe string
---@return JobParse
local function parser(exe)
    return function(stdout, result)
        -- Each retry memoizes one more candidate as missing, so retries are bounded.
        if result.error_string == "init" then
            msg.verbose("yt-dlp candidate " .. exe .. " could not be started; trying the next one")
            missing[exe] = true
            return nil, true
        end
        local data = utils.parse_json(stdout)
        -- For `_type == "playlist"`, the playlist's title is used unchanged.
        if type(data) ~= "table" or type(data.title) ~= "string" or data.title == "" then
            return nil
        end
        return data.title
    end
end

---Whether `filename` is a URL that ytdl_hook would handle.
---@param filename string
---@return boolean
function ytdl.matches(filename)
    local is_url = filename:find("^https?://") ~= nil or filename:find("^ytdl://") ~= nil
    return is_url and mp.get_property_bool("ytdl") == true
end

---Look up the executable and build the URL-independent arguments once, for one scheduling pass.
---@return JobFactory
function ytdl.prepare()
    local exe = executable()
    msg.debug("yt-dlp executable: " .. (exe or "none left to try"))
    if not exe then
        if not warned_none then
            msg.warn("no yt-dlp executable can be started; skipping remote entries")
            warned_none = true
        end
        return function() return nil end
    end
    warned_none = false
    -- Format and subtitle arguments are omitted, because only the title is needed.
    local base_args = {exe, "--no-warnings", "--flat-playlist", "--no-playlist", "-J"}
    local raw_options = mp.get_property_native("options/ytdl-raw-options", {})
    for key, value in pairs(raw_options) do
        base_args[#base_args + 1] = "--" .. key
        -- ytdl_hook passes an empty value only for `proxy`.
        if value ~= "" or key == "proxy" then
            base_args[#base_args + 1] = value
        end
    end
    local parse = parser(exe)

    return function(filename)
        -- Copied, because the queue keeps each job's `args`.
        -- Not via `table.unpack`, which LuaJIT lacks.
        local args = {}
        for i, arg in ipairs(base_args) do
            args[i] = arg
        end
        args[#args + 1] = "--"
        args[#args + 1] = (filename:gsub("^ytdl://", ""))
        return {key = filename, args = args, parse = parse}
    end
end

return ytdl
