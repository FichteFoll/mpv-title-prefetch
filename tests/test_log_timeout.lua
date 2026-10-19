package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

h.setup{opts = {range = -1, timeout = 0.2}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/slow/1",
}}

h.wait_idle(function()
    h.expect_eq(h.count_log(log, "warn", "timed out after 0.2 s: https://example.invalid/slow/1"), 1,
        "timeout warnings")
    h.expect_eq(h.count_log(log, "v", "failed https://example.invalid/slow/1: aborted after the timeout"), 1,
        "failed lines")
    h.expect_eq(h.title(1), nil, "title of index 1")
    h.pass()
end)
