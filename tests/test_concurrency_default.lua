package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

-- `ytdl_batch_size = 1` keeps one URL per start, so that single starts are counted.
h.setup{opts = {range = -1, ytdl_batch_size = 1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/slow/1",
    "https://example.invalid/slow/2",
    "https://example.invalid/slow/3",
    "https://example.invalid/slow/4",
    "https://example.invalid/slow/5",
}}

h.wait_idle(function()
    -- Only the 5th job starts with the 5th slot taken, so the default allows exactly 5.
    h.expect_eq(h.count_log(log, "debug", " (5/5)"), 1, "starts at (5/5)")
    h.pass()
end)
