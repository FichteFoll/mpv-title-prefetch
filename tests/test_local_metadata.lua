package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

h.setup{
    entries = {
        h.fixture("untitled.mkv"),
        h.fixture("titled-1.mkv"),
        h.fixture("stream-title.opus"),
        h.fixture("upper.flac"),
        h.fixture("untitled.mkv"),
    },
    pos = 1,
}

h.wait_until("indices 2 and 3 are titled", function()
    return h.title(2) ~= nil and h.title(3) ~= nil
end, 20, function()
    h.expect_eq(h.title(2), "Opus Title", "title of index 2")
    h.expect_eq(h.title(3), "Upper Title", "title of index 3")
    h.wait_idle(function()
        h.expect_eq(h.title(0), nil, "title of index 0")
        h.expect_eq(h.title(4), nil, "title of index 4")
        h.pass()
    end)
end)
