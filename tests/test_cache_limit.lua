package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local function url(id)
    return "https://example.invalid/video/" .. id
end

h.setup{opts = {range = -1, concurrency = 1, cache_size = 2}, entries = {
    h.fixture("titled-1.mkv"),
    url("a"),
    url("b"),
    url("c"),
}}

-- With concurrency 1 and nearest-first order, a, b and c complete in this order,
-- so a is evicted from the cache of size 2.
h.wait_until("indices 1-3 are titled", function()
    return h.title(1) == "Remote a" and h.title(2) == "Remote b" and h.title(3) == "Remote c"
end, 20, function()
    h.wait_idle(function()
        mp.commandv("loadfile", url("a"), "append")
        mp.commandv("loadfile", url("c"), "append")
        h.wait_until("indices 4 and 5 are titled", function()
            return h.title(4) == "Remote a" and h.title(5) == "Remote c"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.count_calls("/video/a"), 2, "calls for the evicted /video/a")
                h.expect_eq(h.count_calls("/video/b"), 1, "calls for /video/b")
                h.expect_eq(h.count_calls("/video/c"), 1, "calls for the cached /video/c")
                h.pass()
            end)
        end)
    end)
end)
