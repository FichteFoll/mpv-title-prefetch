package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/private/1",
    "https://example.invalid/video/2",
}}

h.wait_idle(function()
    -- The fake answers `private/*` with yt-dlp's generic `<extractor> video #<id>` title.
    h.expect_eq(h.title(1), nil, "title of index 1")
    h.expect_eq(h.title(2), "Remote 2", "title of index 2")
    h.expect_eq(h.count_log(log, "v", "no title for https://example.invalid/private/1"), 1,
        "no-title lines")
    h.pass()
end)
