package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("v")

---@param cond boolean
---@param label string
local function expect_true(cond, label)
    h.expect_eq(cond, true, label)
end

---The ids of the `[#<id>] finished after ` lines, with the number of lines per id.
---@return table<integer, integer>
local function finished_ids()
    local ids = {}
    for _, line in ipairs(log) do
        local id = line.level == "v" and line.text:match("^%[#(%d+)%] finished after %d+%.%d%d s$")
        if id then
            ids[tonumber(id)] = (ids[tonumber(id)] or 0) + 1
        end
    end
    return ids
end

---@param ids table<integer, integer>
---@return integer
local function count(ids)
    local n = 0
    for _ in pairs(ids) do
        n = n + 1
    end
    return n
end

---Whether any outcome line carries `id`.
---@param id integer
---@return boolean
local function has_outcome(id)
    for _, line in ipairs(log) do
        if line.text:find("^%[#" .. id .. "%] resolved ")
            or line.text:find("^%[#" .. id .. "%] no title for ")
            or line.text:find("^%[#" .. id .. "%] failed ") then
            return true
        end
    end
    return false
end

local entries = {}
for n = 1, 4 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = -1, mpv_path = "tp-missing-mpv"}, entries = entries}

h.wait_idle(function()
    h.expect_eq(
        h.count_log(log, "warn",
            "cannot start the local probe executable tp-missing-mpv; skipping local files until mpv_path changes"),
        1, "probe warnings")
    for i = 1, 3 do
        h.expect_eq(h.title(i), nil, "title of index " .. i .. " with a missing probe")
    end

    -- R1, R3: retried subprocesses log their duration but no outcome.
    local first_ids = finished_ids()
    h.expect_eq(count(first_ids), 3, "retried subprocesses")
    for id, lines in pairs(first_ids) do
        h.expect_eq(lines, 1, "duration lines of #" .. id)
        expect_true(not has_outcome(id), "outcome line of the retried subprocess #" .. id)
    end

    -- The skipped entries must not count as failed, so a working probe resolves them.
    h.set_opts{mpv_path = os.getenv("TP_MPV") --[[@as string]]}
    h.wait_idle(function()
        for i = 1, 3 do
            h.expect_eq(h.title(i), "Title " .. (i + 1), "title of index " .. i)
        end

        -- R1: the retry starts new subprocesses with new, still contiguous ids.
        local resolved = 0
        for _, line in ipairs(log) do
            local id, n = line.text:match("^%[#(%d+)%] resolved .-titled%-(%d)%.mkv: Title %d$")
            if id then
                resolved = resolved + 1
                expect_true(first_ids[tonumber(id)] == nil, "retry reuses the id #" .. id)
                h.expect_eq(finished_ids()[tonumber(id)], 1, "duration lines of #" .. id .. " for titled-" .. n)
            end
        end
        h.expect_eq(resolved, 3, "resolved lines")
        local all_ids = finished_ids()
        local total = count(all_ids)
        h.expect_eq(total, 6, "subprocesses")
        for id = 1, total do
            h.expect_eq(all_ids[id], 1, "duration lines of #" .. id)
        end
        h.pass()
    end)
end)
