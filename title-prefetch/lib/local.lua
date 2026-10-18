-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Resolves titles of local files by probing them with a headless mpv.

local utils = require("mp.utils")

local local_files = {}

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
---@param _ SubprocessResult
---@return string?
local function parse(stdout, _)
    local data = utils.parse_json(stdout)
    if type(data) ~= "table" or type(data.title) ~= "string" or data.title == "" then
        return nil
    end
    return data.title
end

---@param filename string
---@param opts Options
---@return Job
local function job(filename, opts)
    return {
        key = filename,
        args = {
            opts.mpv_path,
            "--no-config", "--load-scripts=no", "--idle=no", "--really-quiet",
            "--vo=null", "--ao=null", "--pause", "--ytdl=no",
            "--script=" .. probe_path,
            "--", filename,
        },
        parse = parse,
    }
end

---@param opts Options
---@return JobFactory
function local_files.prepare(opts)
    return function(filename) return job(filename, opts) end
end

return local_files
