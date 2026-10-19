package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

h.setup{
    opts = {range = -1},
    entries = {h.fixture("titled-1.mkv"), h.fixture("titled-2.mkv"), h.fixture("titled-3.mkv")},
}

h.wait_idle(function()
    h.expect_eq(
        h.count_log(log, "debug", "pass: 2 in window, 0 requested, 0 cached, 2 to resolve"), 1,
        "pass lines for the initial resolution")

    mp.commandv("loadfile", h.fixture("titled-2.mkv"), "append")
    h.wait_idle(function()
        h.expect_eq(
            h.count_log(log, "debug", "pass: 3 in window, 0 requested, 1 cached, 0 to resolve"), 1,
            "pass lines for the cached duplicate")
        h.expect_eq(h.title(3), "Title 2", "duplicate title")
        h.expect_eq(h.count_log(log, nil, " 0 cached, 0 to resolve"), 0, "pass lines without work")
        h.pass()
    end)
end)
