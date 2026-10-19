package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/1",
    "https://example.invalid/fail/2",
    h.fixture("untitled.mkv"),
}}

h.wait_idle(function()
    h.expect_eq(h.count_log(log, "v", "resolved https://example.invalid/video/1: Remote 1"), 1,
        "resolved lines")
    h.expect_eq(h.count_log(log, "v",
        "failed https://example.invalid/fail/2: exit status 1: ERROR: [generic] 2: Unable to download webpage"),
        1, "failed lines")
    h.expect_eq(h.count_log(log, "v", "no title for " .. h.fixture("untitled.mkv")), 1, "no-title lines")
    h.expect_eq(h.count_log(log, "debug", "starting https://example.invalid/video/1 ("), 1, "starting lines")
    h.pass()
end)
