package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- Zero-padded, so that the id of one entry is never a substring of another one's.
local function url(n)
    return string.format("https://example.invalid/video/v%03d", n)
end

-- More remote entries than the default `cache_size` of 500 holds.
local entries = {h.fixture("untitled.mkv")}
for n = 1, 501 do
    entries[#entries + 1] = url(n)
end
h.setup{opts = {range = -1, cache_size = -1}, entries = entries}

h.wait_until("indices 1-501 are titled", function()
    for n = 1, 501 do
        if h.title(n) ~= string.format("Remote v%03d", n) then
            return false
        end
    end
    return true
end, 40, function()
    h.wait_idle(function()
        for n = 1, 501 do
            mp.commandv("loadfile", url(n), "append")
        end
        h.wait_until("indices 502-1002 are titled", function()
            for n = 1, 501 do
                if h.title(501 + n) ~= string.format("Remote v%03d", n) then
                    return false
                end
            end
            return true
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(#h.ytdl_calls(), 501, "number of yt-dlp calls")
                h.pass()
            end)
        end)
    end)
end)
