package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- kept.m3u stays an unexpanded entry, because only playing it would expand it.
h.setup{opts = {range = 1}, entries = {
    h.fixture("kept.m3u"),
    h.fixture("titled-2.mkv"),
    h.fixture("titled-3.mkv"),
}, pos = 1}

-- Positive control: the probe works at all.
h.wait_until("index 2 is titled", function()
    return h.title(2) == "Title 3"
end, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(0), nil, "title of the playlist file entry")
        h.pass()
    end)
end)
