package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local function url(id)
    return "https://example.invalid/video/" .. id
end

-- Without a cache, results are still written, but every new entry is fetched again.
h.setup{opts = {range = -1, cache_size = 0}, entries = {
    h.fixture("titled-1.mkv"),
    url("a"),
    url("b"),
}}

h.wait_until("indices 1 and 2 are titled", function()
    return h.title(1) == "Remote a" and h.title(2) == "Remote b"
end, 20, function()
    h.wait_idle(function()
        mp.commandv("loadfile", url("a"), "append")
        h.wait_until("index 3 is titled", function()
            return h.title(3) == "Remote a"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.count_calls("/video/a"), 2, "calls for the uncached /video/a")
                h.pass()
            end)
        end)
    end)
end)
