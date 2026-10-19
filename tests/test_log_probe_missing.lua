package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("warn")

local entries = {}
for n = 1, 4 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = -1, mpv_path = "tp-missing-mpv"}, entries = entries}

h.wait_idle(function()
    h.expect_eq(
        h.count_log(log, "warn",
            "cannot start the local probe executable tp-missing-mpv; skipping local files until mpv_path changes"),
        1, "probe warnings")
    for i = 1, 3 do
        h.expect_eq(h.title(i), nil, "title of index " .. i .. " with a missing probe")
    end
    -- The skipped entries must not count as failed, so a working probe resolves them.
    h.set_opts{mpv_path = os.getenv("TP_MPV") --[[@as string]]}
    h.wait_idle(function()
        for i = 1, 3 do
            h.expect_eq(h.title(i), "Title " .. (i + 1), "title of index " .. i)
        end
        h.pass()
    end)
end)
