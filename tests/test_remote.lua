package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

mp.set_property("ytdl-raw-options", "cookies=/x")
h.setup{entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/a",
    "ytdl://https://example.invalid/video/b",
    "https://example.invalid/fail/c",
}}

h.wait_until("indices 1 and 2 are titled", function()
    return h.title(1) == "Remote a" and h.title(2) == "Remote b"
end, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(3), nil, "title of index 3")
        h.expect_eq(h.count_calls("--cookies /x -- https://example.invalid/video/b"), 1,
            "calls with raw options and stripped ytdl:// prefix")
        h.pass()
    end)
end)
