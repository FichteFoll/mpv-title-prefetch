package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

local entries = {h.fixture("titled-1.mkv")}
for id = 1, 8 do
    entries[#entries + 1] = "https://example.invalid/video/" .. id
end

-- With `concurrency` at least the number of URLs, the first pass that sees them starts all of them,
-- and every later pass finds them running or titled, so exactly one pass needs a job.
h.setup{opts = {range = -1, concurrency = 10}, entries = entries}

h.wait_until("indices 1-8 are titled", function()
    for id = 1, 8 do
        if h.title(id) ~= "Remote " .. id then
            return false
        end
    end
    return true
end, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.count_log(log, "debug", "yt-dlp executable:"), 1, "yt-dlp executable lookups")
        h.pass()
    end)
end)
