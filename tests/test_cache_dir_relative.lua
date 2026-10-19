package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

local function url(id)
    return "https://example.invalid/video/" .. id
end

-- A relative `cache_dir` disables the cache instead of writing below the working directory.
h.setup{opts = {range = -1, cache_dir = "title-prefetch-relative-test"}, entries = {
    h.fixture("titled-1.mkv"),
    url("a"),
}}

h.wait_until("index 1 is titled", function()
    return h.title(1) == "Remote a"
end, 20, function()
    h.wait_idle(function()
        mp.commandv("loadfile", url("a"), "append")
        h.wait_until("index 2 is titled", function()
            return h.title(2) == "Remote a"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.count_calls("/video/a"), 2, "calls for /video/a")
                h.expect_eq(utils.file_info("title-prefetch-relative-test"), nil,
                    "file info of the relative cache directory")
                h.pass()
            end)
        end)
    end)
end)
