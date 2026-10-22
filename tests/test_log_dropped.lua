package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

-- `ytdl_batch_size = 1` keeps one URL per start, so that single starts are counted.
h.setup{opts = {range = -1, concurrency = 1, ytdl_batch_size = 1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/slow/1",
    "https://example.invalid/slow/2",
    "https://example.invalid/slow/3",
}}

-- With concurrency 1, one slow job runs and two are pending when the range drops to 0.
-- Every earlier pass wants the same keys, so it drops nothing.
h.wait_until("a slow job was started", function()
    return h.count_log(log, "debug", "starting https://example.invalid/slow/") > 0
end, 20, function()
    h.set_opts{range = 0}
    h.wait_idle(function()
        h.expect_eq(h.count_log(log, "debug", "dropped 2 pending jobs"), 1, "dropped lines")
        -- With concurrency 1, every start counts only the job itself.
        h.expect_eq(h.count_log(log, "debug", " (1/1)"), h.count_log(log, "debug", "starting "),
            "start counts")
        h.pass()
    end)
end)
