package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- Zero-padded, so that the id of one entry is never a substring of another one's.
local function url(n)
    return string.format("https://example.invalid/video/v%03d", n)
end

-- The current entry has no title, so its playback refresh caches nothing,
-- and the 501 remote titles are the only cache entries.
local entries = {h.fixture("untitled.mkv")}
for n = 1, 501 do
    entries[#entries + 1] = url(n)
end
h.setup{opts = {range = -1, concurrency = 1}, entries = entries}

-- With concurrency 1 and nearest-first order, v001 completes first,
-- so the default `cache_size` of 500 evicts exactly v001.
h.wait_until("index 501 is titled", function()
    return h.title(501) == "Remote v501"
end, 40, function()
    h.wait_idle(function()
        -- Cache hits are written in the next pass,
        -- before the re-fetch of v001 evicts v002.
        mp.commandv("loadfile", url(2), "append")
        mp.commandv("loadfile", url(501), "append")
        mp.commandv("loadfile", url(1), "append")
        h.wait_until("indices 502-504 are titled", function()
            return h.title(502) == "Remote v002" and h.title(503) == "Remote v501"
                and h.title(504) == "Remote v001"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.count_calls("/video/v001"), 2, "calls for the evicted v001")
                h.expect_eq(h.count_calls("/video/v002"), 1, "calls for the cached v002")
                h.expect_eq(h.count_calls("/video/v501"), 1, "calls for the cached v501")
                h.pass()
            end)
        end)
    end)
end)
