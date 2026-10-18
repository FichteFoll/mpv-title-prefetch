package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local function url(id)
    return "https://example.invalid/video/" .. id
end

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    url("a"),
    url("b"),
}}

h.wait_until("indices 1 and 2 are titled", function()
    return h.title(1) == "Remote a" and h.title(2) == "Remote b"
end, 20, function()
    h.wait_idle(function()
        mp.commandv("loadfile", url("a"), "append")
        mp.commandv("loadfile", url("b"), "append")
        mp.commandv("loadfile", url("a"), "append")
        h.wait_until("indices 3-5 are titled from the cache", function()
            return h.title(3) == "Remote a" and h.title(4) == "Remote b" and h.title(5) == "Remote a"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.count_calls("/video/a"), 1, "calls for /video/a")
                h.expect_eq(h.count_calls("/video/b"), 1, "calls for /video/b")
                h.pass()
            end)
        end)
    end)
end)
