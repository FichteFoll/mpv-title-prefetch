package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

-- Opening the cache removes temporary files that a crash left behind,
-- but keeps recent ones, which another instance may be about to rename,
-- and with `cache_size=0` it touches no file at all.
local tmp = os.getenv("TP_TMP") --[[@as string]]
local stale = "0123456789abcdef.json.4242.tmp"
local fresh = "fedcba9876543210.json.4343.tmp"

---@param dir string
---@return string dir
local function prepare(dir)
    mp.command_native({name = "subprocess", playback_only = false, args = {"mkdir", "-p", dir}})
    for _, name in ipairs({stale, fresh}) do
        local f = assert(io.open(utils.join_path(dir, name), "w"))
        f:close()
    end
    mp.command_native({name = "subprocess", playback_only = false,
        args = {"touch", "-d", "@1000000000", utils.join_path(dir, stale)}})
    return dir
end

---@param dir string
---@param name string
---@return boolean
local function exists(dir, name)
    return utils.file_info(utils.join_path(dir, name)) ~= nil
end

local cleaned = prepare(utils.join_path(tmp, "cleaned"))
local untouched = prepare(utils.join_path(tmp, "untouched"))

h.setup{opts = {range = -1, cache_dir = cleaned}, entries = {h.fixture("titled-1.mkv")}}

h.wait_idle(function()
    h.expect_eq(exists(cleaned, stale), false, "stale temporary file present")
    h.expect_eq(exists(cleaned, fresh), true, "fresh temporary file present")
    h.set_opts{cache_size = 0, cache_dir = untouched}
    h.wait_idle(function()
        h.expect_eq(exists(untouched, stale), true, "stale temporary file present with cache_size=0")
        h.pass()
    end)
end)
