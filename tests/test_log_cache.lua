package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

local log = h.capture_log("debug")

local tmp = os.getenv("TP_TMP") --[[@as string]]
local a = utils.join_path(tmp, "a")
local b = utils.join_path(tmp, "b")
mp.command_native({name = "subprocess", playback_only = false, args = {"mkdir", "-p", b}})

---@param dir string
---@return string[] names
local function entry_files(dir)
    ---@type string[]
    local names = {}
    for _, name in ipairs(utils.readdir(dir, "files") or {}) do
        if name:match("%.json$") then
            names[#names + 1] = name
        end
    end
    return names
end

---@param path string
---@return integer count of `ignoring cache file` lines for `path`
local function ignored(path)
    -- The name that belongs to `path` is unknown, so every garbage file's name is tried.
    local count = 0
    for _, name in ipairs(entry_files(b)) do
        count = count + h.count_log(log, "debug", "ignoring cache file " .. name .. " for " .. path)
    end
    return count
end

-- Index 0 plays, so the plugin caches its title on `file-loaded`, and indices 1 and 2 are probed.
h.setup{opts = {range = -1, cache_dir = a},
    entries = {h.fixture("titled-1.mkv"), h.fixture("titled-2.mkv"), h.fixture("titled-3.mkv")}}

-- Fills `b` with unparsable files under the names of `a`'s entries,
-- since the test cannot tell which name belongs to which entry.
local function corrupt_into_b()
    local names = entry_files(a)
    h.expect_eq(#names, 3, "files in " .. a)
    for _, name in ipairs(names) do
        local f = assert(io.open(utils.join_path(b, name), "w"))
        f:write("garbage")
        f:close()
    end
end

local function expect_eviction()
    h.set_opts{cache_size = 1}
    h.wait_idle(function()
        h.expect_eq(h.count_log(log, "debug", "evicted 2 cache entries"), 1, "eviction lines")
        h.pass()
    end)
end

-- The reopened cache has nothing in memory, so looking up untitled duplicates reads the garbage files.
local function expect_ignored_files()
    mp.commandv("loadfile", h.fixture("titled-2.mkv"), "append")
    mp.commandv("loadfile", h.fixture("titled-3.mkv"), "append")
    h.wait_idle(function()
        h.expect_eq(ignored(h.fixture("titled-2.mkv")) > 0, true, "ignored file lines for titled-2")
        h.expect_eq(ignored(h.fixture("titled-3.mkv")) > 0, true, "ignored file lines for titled-3")
        h.expect_eq(h.title(3), "Title 2", "title of index 3")
        h.expect_eq(h.title(4), "Title 3", "title of index 4")
        expect_eviction()
    end)
end

h.wait_idle(function()
    corrupt_into_b()
    -- Indices 1 and 2 are titled and index 0 is not in the window, so switching writes no title.
    h.set_opts{cache_dir = b}
    h.wait_idle(function()
        h.expect_eq(h.count_log(log, "v", "title cache " .. b .. ": 3 entries, limit 500"), 1,
            "cache opening lines")
        expect_ignored_files()
    end)
end)
