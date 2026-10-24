package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

local log = h.capture_log("debug")

local dir = utils.join_path(os.getenv("TP_TMP") --[[@as string]], "cache")
local foreign = utils.join_path(dir, "0123456789abcdef.json")
local keep = utils.join_path(dir, "keep.txt")
local tmp_file = utils.join_path(dir, "0123456789abcdef.json.1.tmp")

local function clear_cache()
    mp.commandv("script-message-to", "title_prefetch", "clear-cache")
end

---@param path string
---@param content string
local function write_file(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

---@param path string
---@return boolean
local function exists(path)
    return utils.file_info(path) ~= nil
end

---@return integer
local function entry_file_count()
    local count = 0
    for _, name in ipairs(utils.readdir(dir, "files") or {}) do
        if name:match("^%x+%.json$") then
            count = count + 1
        end
    end
    return count
end

-- R5, R6: without a cache directory, only the failed markers are forgotten.
-- Only `fail/x` failed again; the playing entry is never retried.
local function step_no_directory()
    h.set_opts{cache_dir = ""}
    h.wait_idle(function()
        clear_cache()
        h.wait_idle(function()
            h.expect_eq(h.count_log(log, "info",
                "clear-cache: no cache directory in use, failed entries forgotten: 1"), 1,
                "info lines without a directory")
            h.pass()
        end)
    end)
end

-- R2: a formerly cached file is resolved again, not served from memory.
local function step_resolved_again()
    mp.commandv("loadfile", "https://example.invalid/video/a", "append")
    h.wait_until("index 3 is titled", function()
        return h.title(3) == "Remote a"
    end, 20, function()
        h.wait_idle(function()
            h.expect_eq(h.count_calls("/video/a"), 2, "calls for the formerly cached entry")
            step_no_directory()
        end)
    end)
end

-- R1, R3, R4, R5: the entry files go, other files stay, and failed entries are retried.
local function step_clear()
    write_file(foreign,
        '{"filename":"https://example.invalid/video/foreign","title":"Foreign"}')
    write_file(keep, "keep")
    write_file(tmp_file, "tmp")
    clear_cache()
    h.wait_idle(function()
        h.expect_eq(entry_file_count(), 0, "entry files left")
        h.expect_eq(exists(keep), true, "keep.txt exists")
        h.expect_eq(exists(tmp_file), true, "temporary file exists")
        h.expect_eq(h.title(1), "Remote a", "title of index 1")
        h.expect_eq(h.count_calls("/fail/x"), 2, "calls for the failed entry")
        h.expect_eq(h.count_log(log, "info",
            "clear-cache: cache entries removed from " .. dir .. ": 2, failed entries forgotten: 2"), 1,
            "info lines with a directory")
        step_resolved_again()
    end)
end

-- Index 0 plays without a title, so it is marked as failed together with `fail/x`.
h.setup{opts = {range = -1},
    entries = {h.fixture("untitled.mkv"), "https://example.invalid/video/a", "https://example.invalid/fail/x"}}
h.wait_until("index 1 is titled", function()
    return h.title(1) == "Remote a"
end, 20, function()
    h.wait_until("the playing entry is loaded", function()
        return mp.get_property("file-format") ~= nil
    end, 20, function()
        h.wait_idle(step_clear)
    end)
end)
