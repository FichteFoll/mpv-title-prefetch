package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

---@param cond boolean
---@param label string
local function expect_true(cond, label)
    h.expect_eq(cond, true, label)
end

local untitled = h.fixture("untitled.mkv")

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/1",
    "https://example.invalid/fail/2",
    "https://example.invalid/slow/3",
    untitled,
}}

---The run ids of the lines at `level` whose text after the `[#<id>] ` prefix starts with `text`.
---@param level string
---@param text string
---@return integer[]
local function ids_of(level, text)
    local ids = {}
    for _, line in ipairs(log) do
        local id, rest = line.text:match("^%[#(%d+)%] (.*)$")
        if line.level == level and rest and rest:sub(1, #text) == text then
            ids[#ids + 1] = tonumber(id)
        end
    end
    return ids
end

---@param level string
---@param text string
---@return integer
local function id_of(level, text)
    local ids = ids_of(level, text)
    h.expect_eq(#ids, 1, "prefixed lines starting with " .. text)
    return ids[1]
end

h.wait_idle(function()
    h.expect_eq(h.count_log(log, "v", "resolved https://example.invalid/video/1: Remote 1"), 1,
        "resolved lines")
    h.expect_eq(h.count_log(log, "v",
        "failed https://example.invalid/fail/2: exit status 1: ERROR: [generic] 2: Unable to download webpage"),
        1, "failed lines")
    h.expect_eq(h.count_log(log, "v", "no title for " .. untitled), 1, "no-title lines")
    h.expect_eq(h.count_log(log, "debug", "starting https://example.invalid/video/1 ("), 1, "starting lines")

    -- R1, R2, R3: every subprocess gets an incremental id that tags its lines
    -- and one duration line, which comes before its outcome lines.
    local ytdl_id = id_of("debug", "starting https://example.invalid/video/1 (")
    h.expect_eq(id_of("debug", "starting https://example.invalid/fail/2 ("), ytdl_id, "id of fail/2 start")
    h.expect_eq(id_of("debug", "starting https://example.invalid/slow/3 ("), ytdl_id, "id of slow/3 start")
    local probe_id = id_of("debug", "starting " .. untitled .. " (")
    expect_true(probe_id ~= ytdl_id, "probe and yt-dlp subprocesses share an id")

    if not (ytdl_id and probe_id) then
        return
    end

    h.expect_eq(id_of("v", "resolved https://example.invalid/video/1: Remote 1"), ytdl_id, "id of video/1 outcome")
    h.expect_eq(id_of("v", "failed https://example.invalid/fail/2: exit status 1: ERROR: "), ytdl_id,
        "id of fail/2 outcome")
    h.expect_eq(id_of("v", "resolved https://example.invalid/slow/3: Slow 3"), ytdl_id, "id of slow/3 outcome")
    h.expect_eq(id_of("v", "no title for " .. untitled), probe_id, "id of the no-title outcome")

    local seen = {}
    for _, id in ipairs{ytdl_id, probe_id} do
        seen[id] = true
    end
    local distinct = 0
    for id in pairs(seen) do
        distinct = distinct + 1
        expect_true(id >= 1 and id <= 2, "id " .. id .. " is within 1..2")
    end
    h.expect_eq(distinct, 2, "distinct ids")

    ---@type table<integer, number[]>
    local durations = {[ytdl_id] = {}, [probe_id] = {}}
    for index, line in ipairs(log) do
        if line.text:find("finished after", 1, true) then
            h.expect_eq(line.level, "v", "level of the duration line")
            local id, seconds = line.text:match("^%[#(%d+)%] finished after (%d+%.%d%d) s$")
            expect_true(id ~= nil, "format of " .. line.text)
            if id then
                local list = durations[tonumber(id)]
                expect_true(list ~= nil, "id of " .. line.text)
                if list then
                    list[#list + 1] = tonumber(seconds)
                end
                for earlier = 1, index - 1 do
                    local text = log[earlier].text
                    expect_true(not (text:find("^%[#" .. id .. "%] resolved ")
                        or text:find("^%[#" .. id .. "%] no title for ")
                        or text:find("^%[#" .. id .. "%] failed ")), "outcome line before " .. line.text)
                end
            end
        end
    end
    h.expect_eq(h.count_log(log, nil, "finished after"), 2, "duration lines")
    h.expect_eq(#durations[ytdl_id], 1, "duration lines of the yt-dlp subprocess")
    h.expect_eq(#durations[probe_id], 1, "duration lines of the probe subprocess")
    expect_true(#durations[ytdl_id] == 1 and durations[ytdl_id][1] >= 0.5, "duration of the yt-dlp subprocess")
    h.pass()
end)
