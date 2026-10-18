-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Bounded FIFO cache of titles. Pure; requires nothing from mpv.

local cache = {}

---@class Cache
---@field private limit integer maximum number of entries; 0 = none, negative = unlimited
---@field private values table<string, string>
---@field private order string[] keys, oldest first
local Cache = {}
Cache.__index = Cache

---@param limit integer maximum number of entries; 0 = none, negative = unlimited
---@return Cache
function cache.new(limit)
    return setmetatable({limit = limit, values = {}, order = {}}, Cache)
end

---@param key string
---@return string?
function Cache:get(key)
    return self.values[key]
end

---Store `value` under `key` as the newest entry, also when `key` already exists.
---@param key string
---@param value string
function Cache:put(key, value)
    self:remove(key)
    self.values[key] = value
    self.order[#self.order + 1] = key
    self:evict()
end

---@param key string
function Cache:remove(key)
    if not self.values[key] then
        return
    end
    self.values[key] = nil
    for i, existing in ipairs(self.order) do
        if existing == key then
            table.remove(self.order, i)
            return
        end
    end
end

---@param limit integer maximum number of entries; 0 = none, negative = unlimited
function Cache:set_limit(limit)
    self.limit = limit
    self:evict()
end

---Remove the oldest entries until the limit holds.
---@private
function Cache:evict()
    if self.limit < 0 then
        return
    end
    local excess = #self.order - self.limit
    if excess <= 0 then
        return
    end
    for i = 1, excess do
        self.values[self.order[i]] = nil
    end
    ---@type string[]
    local kept = {}
    for i = excess + 1, #self.order do
        kept[#kept + 1] = self.order[i]
    end
    self.order = kept
end

return cache
