package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

local function resolve_range(...)
    mp.commandv("script-message-to", "title_prefetch", "resolve-range", ...)
end

---@param first integer
---@param last integer
---@return fun(): boolean
local function titled(first, last)
    return function()
        for i = first, last do
            if h.title(i) ~= "Title " .. (i + 1) then
                return false
            end
        end
        return true
    end
end

-- Index i has the title "Title <i+1>".
local entries = {}
for n = 1, 15 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
-- `range=0` leaves the window empty, so only requested entries are resolved.
h.setup{opts = {range = 0}, entries = entries, pos = 0}

-- R4: a titled entry is dropped from the request without a resolver call.
local function step_titled()
    mp.commandv("loadfile", "https://example.invalid/video/kept", "append")
    mp.set_property("playlist/16/title", "Kept")
    resolve_range("16")
    h.wait_idle(function()
        h.expect_eq(h.title(16), "Kept", "title of the titled entry")
        h.expect_eq(h.count_calls("/video/kept"), 0, "calls for the titled entry")
        h.pass()
    end)
end

-- R2, R7, R8: invalid requests warn and are ignored, a request beyond the end is empty.
local function step_invalid()
    resolve_range("3", "2")
    resolve_range("-1", "3")
    resolve_range("x")
    resolve_range("2", "y")
    resolve_range()
    resolve_range("50")
    h.wait_idle(function()
        h.expect_eq(h.title(2), nil, "title of index 2")
        h.expect_eq(h.title(3), nil, "title of index 3")
        h.expect_eq(h.count_log(log, "warn", "resolve-range: expected"), 5, "warnings")
        h.expect_eq(h.count_log(log, "warn",
            "resolve-range: expected non-negative integers <first> [<last>] with first <= last, got: 2 y"),
            1, "warning for 2 y")
        h.expect_eq(h.count_log(log, "debug", "resolve-range 50-50: 0 entries, "), 1,
            "request line beyond the end")
        step_titled()
    end)
end

-- R3: an untitled duplicate of the current file gets its title from the cache, not from a probe.
local function step_current_duplicate()
    mp.commandv("loadfile", h.fixture("titled-1.mkv"), "append")
    resolve_range("15")
    h.wait_until("index 15 is titled", function()
        return h.title(15) == "Title 1"
    end, 20, function()
        h.wait_idle(function()
            h.expect_eq(h.count_log(log, "debug", "starting " .. h.fixture("titled-1.mkv")), 0,
                "probes of the current file")
            h.expect_eq(
                h.count_log(log, "debug", "pass: 0 in window, 1 requested, 1 cached, 0 to resolve"), 1,
                "pass lines for the cached duplicate")
            step_invalid()
        end)
    end)
end

-- R1: a single argument requests one entry, and equal bounds are inclusive.
local function step_single()
    resolve_range("5")
    resolve_range("7", "7")
    h.wait_until("indices 5 and 7 are titled", function()
        return titled(5, 5)() and titled(7, 7)()
    end, 20, function()
        h.wait_idle(function()
            h.expect_eq(h.title(4), nil, "title of index 4")
            h.expect_eq(h.title(6), nil, "title of index 6")
            h.expect_eq(h.title(8), nil, "title of index 8")
            step_current_duplicate()
        end)
    end)
end

-- R2: `last` beyond the end is clamped.
local function step_clamped()
    resolve_range("13", "99")
    h.wait_until("indices 13 and 14 are titled", titled(13, 14), 20, step_single)
end

-- R1, R8, R9: exactly the requested entries are resolved, with `range=0`.
resolve_range("10", "12")
h.wait_until("indices 10-12 are titled", titled(10, 12), 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(9), nil, "title of index 9")
        h.expect_eq(h.title(13), nil, "title of index 13")
        h.expect_eq(h.count_log(log, "debug", "resolve-range 10-12: 3 entries, 3 requested"), 1,
            "request line")
        -- The default concurrency of 5 starts all three jobs in one pass,
        -- and later passes find them running, so they log nothing.
        h.expect_eq(
            h.count_log(log, "debug", "pass: 0 in window, 3 requested, 0 cached, 3 to resolve"), 1,
            "pass lines for the request")
        step_clamped()
    end)
end)
