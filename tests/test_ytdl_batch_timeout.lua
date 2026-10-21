package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

-- video/1 is answered at once and slow/2 only after 0.5 s,
-- so the timeout aborts the batch after the line of video/1 was printed.
h.setup{opts = {range = -1, timeout = 0.3}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/1",
    "https://example.invalid/slow/2",
}}

h.wait_idle(function()
    h.expect_eq(h.title(1), "Remote 1", "title of index 1")
    h.expect_eq(h.title(2), nil, "title of index 2")
    h.expect_eq(h.count_log(log, "warn",
        "timed out after 0.3 s: https://example.invalid/video/1, https://example.invalid/slow/2"),
        1, "timeout warnings")
    h.expect_eq(h.count_log(log, "v", "failed https://example.invalid/slow/2: aborted after the timeout"), 1,
        "failed lines")
    h.pass()
end)
