-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Resolves titles of local files by probing them with a headless mpv.

local msg = require("mp.msg")
local utils = require("mp.utils")

local local_files = {}

-- Probe executables whose run failed because they could not be started.
---@type table<string, true>
local missing = {}

local probe_path = utils.join_path(
    assert(mp.get_script_directory(), "title-prefetch must be installed as a directory script"),
    "lib/probe.lua"
)

---@param s string
---@return string
local function percent_decode(s)
    return (s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

---@param filename string playlist entry filename
---@return string? path local path, or nil for other protocols
local function local_path(filename)
    local rest = filename:match("^file://(.*)$")
    if rest then
        return percent_decode(rest)
    end
    if filename:find("^%a[%w+.-]*://") then
        return nil
    end
    return filename
end

---Whether `filename` is a regular local file, given as a plain path or a `file://` URL.
---@param filename string
---@return boolean
function local_files.matches(filename)
    local path = local_path(filename)
    if not path then
        return false
    end
    local info = utils.file_info(path)
    return info ~= nil and info.is_file
end

---@param stdout string
---@return string?
local function probed_title(stdout)
    local data = utils.parse_json(stdout)
    if type(data) ~= "table" or type(data.title) ~= "string" or data.title == "" then
        return nil
    end
    return data.title
end

---@param exe string probe executable
---@return Runner
local function runner(exe)
    return {
        batch_size = 1,
        args = function(keys)
            return {
                exe,
                "--no-config", "--load-scripts=no", "--idle=no", "--really-quiet",
                "--vo=null", "--ao=null", "--pause", "--ytdl=no",
                "--script=" .. probe_path,
                "--", keys[1],
            }
        end,
        parse = function(keys, stdout, result)
            -- The retry keeps the entry out of `failed`, so it is probed once `mpv_path` changes.
            if result.error_string == "init" then
                if not missing[exe] then
                    msg.warn("cannot start the local probe executable " .. exe
                        .. "; skipping local files until mpv_path changes")
                end
                missing[exe] = true
                return {retry = true}
            end
            if result.status ~= 0 or result.killed_by_us then
                return {}
            end
            return {keys = {[keys[1]] = {title = probed_title(stdout)}}}
        end,
    }
end

---@param opts Options
---@return JobFactory
function local_files.prepare(opts)
    local exe = opts.mpv_path
    if missing[exe] then
        return function() return nil end
    end
    local probe = runner(exe)
    return function(filename) return {key = filename, runner = probe} end
end

return local_files
