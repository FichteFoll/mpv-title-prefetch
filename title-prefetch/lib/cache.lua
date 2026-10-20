-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Bounded FIFO cache of titles, persisted in a directory.
-- Each entry is a file `<hash>.json` holding `{"filename": <key>, "title": <title>}`,
-- written through on every change, and its age is the file's `mtime`.
-- Concurrent mpv instances share the directory without locking,
-- since each write replaces a single entry's file atomically.

local msg = require("mp.msg")
local utils = require("mp.utils")

local cache = {}

---@class Cache
---@field private dir string? absolute directory; nil when disabled
---@field private limit integer maximum number of entries; 0 = none, negative = unlimited
---@field private order string[] file names, oldest first
---@field private indexed table<string, true> the file names in `order`
---@field private keys table<string, string> normalized key by file name, for loaded entries
---@field private values table<string, string> title by normalized key, for loaded entries
local Cache = {}
Cache.__index = Cache

---@param dir string?
---@param limit integer
---@param names? string[] file names, oldest first
---@return Cache
local function new(dir, limit, names)
    ---@type table<string, true>
    local indexed = {}
    for _, name in ipairs(names or {}) do
        indexed[name] = true
    end
    return setmetatable({dir = dir, limit = limit, order = names or {}, indexed = indexed, keys = {}, values = {}}, Cache)
end

-- mpv offers Lua scripts no hash function, and it may run Lua 5.1 without a bit library,
-- so two polynomial hashes in plain doubles give 62 bits.
-- All intermediate values stay below 2^40, which doubles represent exactly.
-- A collision is harmless, since the file stores the full key.
---@param key string
---@return string
local function hash(key)
    local h1, h2 = 0, 0
    for i = 1, #key do
        local byte = key:byte(i)
        h1 = (h1 * 257 + byte) % 2147483647
        h2 = (h2 * 257 + byte) % 2147483629
    end
    return string.format("%08x%08x", h1, h2)
end

---Make local paths absolute, so that a relative path stays the same entry in another working directory.
---@param filename string
---@return string
local function normalize(filename)
    if filename:match("^%a[%w+.-]*://") then
        return filename
    end
    return mp.command_native({"normalize-path", filename})
end

---@param path string
---@return boolean
local function is_absolute(path)
    return path:match("^/") ~= nil or path:match("^%a:[/\\]") ~= nil or path:match("^\\\\") ~= nil
end

---@param path string
---@return boolean
local function is_dir(path)
    local info = utils.file_info(path)
    return info ~= nil and info.is_dir
end

---@param path string
local function make_dir(path)
    local args = {"mkdir", "-p", path}
    if mp.get_property("platform") == "windows" then
        args = {"cmd", "/d", "/c", "mkdir", path}
    end
    mp.command_native({name = "subprocess", playback_only = false, args = args})
end

-- A write takes far less than this, so an older temporary file was left behind by a crash
-- between writing and renaming it, while a younger one may belong to a running instance.
local STALE_TMP_AGE_S = 60

---@param path string
---@param remove_stale boolean remove temporary files left behind by a crash
---@return string[] names the entry files in `path`, oldest first; no file is read
local function scan(path, remove_stale)
    local now = os.time()
    ---@type {name: string, mtime: integer}[]
    local files = {}
    for _, name in ipairs(utils.readdir(path, "files") or {}) do
        local is_entry = name:match("^%x+%.json$") ~= nil
        local is_tmp = remove_stale and name:match("^%x+%.json%.%d+%.tmp$") ~= nil
        -- Nil when the file was deleted meanwhile.
        local info = (is_entry or is_tmp) and utils.file_info(utils.join_path(path, name))
        if info and is_entry then
            files[#files + 1] = {name = name, mtime = info.mtime}
        elseif info and now - info.mtime > STALE_TMP_AGE_S then
            os.remove(utils.join_path(path, name))
        end
    end
    table.sort(files, function(a, b)
        if a.mtime ~= b.mtime then
            return a.mtime < b.mtime
        end
        return a.name < b.name
    end)
    ---@type string[]
    local names = {}
    for i, file in ipairs(files) do
        names[i] = file.name
    end
    return names
end

---Open the cache in `dir`, creating the directory if needed.
---@param dir string option value, expanded with `expand-path`; empty = disabled
---@param limit integer maximum number of entries; 0 = none, negative = unlimited
---@return Cache
function cache.open(dir, limit)
    if dir == "" then
        return new(nil, limit)
    end
    local path = mp.command_native({"expand-path", dir}) --[[@as string]]
    if not is_absolute(path) then
        msg.warn("cache_dir is not an absolute path, disabling the cache: " .. path)
        return new(nil, limit)
    end
    if not utils.file_info(path) then
        make_dir(path)
    end
    if not is_dir(path) then
        msg.warn("cache_dir is not a directory, disabling the cache: " .. path)
        return new(nil, limit)
    end

    -- With `limit == 0`, the directory is left alone, as other instances may still use it.
    local self = new(path, limit, scan(path, limit ~= 0))
    -- Evicts down to `limit`.
    self:set_limit(limit)
    msg.verbose("title cache " .. path .. ": " .. self:count() .. " entries, limit " .. limit)
    return self
end

---@private
---@return boolean
function Cache:active()
    return self.dir ~= nil and self.limit ~= 0
end

---@private
---@param name string
---@return string
function Cache:file_path(name)
    return utils.join_path(self.dir --[[@as string]], name)
end

---@private
---@param name string
function Cache:append(name)
    self.order[#self.order + 1] = name
    self.indexed[name] = true
end

---@private
---@param name string
function Cache:unindex(name)
    if not self.indexed[name] then
        return
    end
    self.indexed[name] = nil
    for i, existing in ipairs(self.order) do
        if existing == name then
            table.remove(self.order, i)
            return
        end
    end
end

---@private
---@param name string
---@param key string
---@param value string
function Cache:load(name, key, value)
    -- On a hash collision, the name's previous key no longer has a file.
    local previous = self.keys[name]
    if previous and previous ~= key then
        self.values[previous] = nil
    end
    self.keys[name] = key
    self.values[key] = value
end

---@param key string
---@return string?
function Cache:get(key)
    if not self:active() then
        return nil
    end
    key = normalize(key)
    local value = self.values[key]
    if value then
        return value
    end
    local name = hash(key) .. ".json"
    local f = io.open(self:file_path(name), "r")
    if not f then
        return nil
    end
    local data = utils.parse_json(f:read("*a"))
    f:close()
    if type(data) ~= "table" or data.filename ~= key or type(data.title) ~= "string" then
        msg.debug("ignoring cache file " .. name .. " for " .. key)
        return nil
    end
    self:load(name, key, data.title)
    if not self.indexed[name] then
        self:append(name)
    end
    self:evict()
    return data.title
end

---@param path string
---@param content string
---@return boolean ok
---@return string? error
local function write_atomically(path, content)
    local tmp = path .. "." .. utils.getpid() .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then
        return false, err
    end
    local ok, write_err = f:write(content)
    -- Buffered write errors, such as a full disk, may only surface on close.
    local closed, close_err = f:close()
    if not ok or not closed then
        os.remove(tmp)
        return false, write_err or close_err
    end
    if os.rename(tmp, path) then
        return true
    end
    -- Windows cannot rename onto an existing file.
    os.remove(path)
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        os.remove(tmp)
        return false, rename_err
    end
    return true
end

-- `utils.format_json` orders object keys by table traversal, which varies between runs,
-- so the object is assembled from encoded strings to keep the files reproducible.
---@param key string
---@param value string
---@return string
local function format_entry(key, value)
    return '{"filename":' .. utils.format_json(key) .. ',"title":' .. utils.format_json(value) .. "}"
end

---Store `value` under `key` as the newest entry, also when `key` already exists.
---@param key string
---@param value string
function Cache:put(key, value)
    if not self:active() then
        return
    end
    key = normalize(key)
    local name = hash(key) .. ".json"
    local ok, err = write_atomically(self:file_path(name), format_entry(key, value))
    if not ok then
        msg.warn("cannot write the title cache entry for " .. key .. ": " .. tostring(err))
    end
    self:load(name, key, value)
    self:unindex(name)
    self:append(name)
    self:evict()
end

---@param key string
function Cache:remove(key)
    if not self:active() then
        return
    end
    key = normalize(key)
    local name = hash(key) .. ".json"
    os.remove(self:file_path(name))
    -- On a hash collision, the file held another key, whose value goes with it.
    local loaded = self.keys[name]
    if loaded then
        self.values[loaded] = nil
    end
    self.values[key] = nil
    self.keys[name] = nil
    self:unindex(name)
end

---Return the number of indexed entries, whether loaded or not.
---@return integer
function Cache:count()
    return #self.order
end

---@param limit integer maximum number of entries; 0 = none, negative = unlimited
function Cache:set_limit(limit)
    self.limit = limit
    self:evict()
end

---Remove the oldest entries and their files until the limit holds.
---@private
function Cache:evict()
    if not self.dir or self.limit <= 0 then
        return
    end
    local excess = #self.order - self.limit
    if excess <= 0 then
        return
    end
    msg.debug("evicted " .. excess .. " cache entries")
    for i = 1, excess do
        local name = self.order[i]
        local key = self.keys[name]
        if key then
            self.values[key] = nil
            self.keys[name] = nil
        end
        self.indexed[name] = nil
        os.remove(self:file_path(name))
    end
    ---@type string[]
    local kept = {}
    for i = excess + 1, #self.order do
        kept[#kept + 1] = self.order[i]
    end
    self.order = kept
end

return cache
