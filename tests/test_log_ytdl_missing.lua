package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("warn")

local WARNING = "no yt-dlp executable can be started; skipping remote entries"

---Append `url` to force another pass, since a change of `ytdl_hook-*` options alone triggers none.
---@param url string
local function append(url)
    mp.commandv("loadfile", url, "append")
end

h.setup{
    opts = {range = -1},
    script_opts = {"ytdl_hook-ytdl_path=tp-missing-exe"},
    entries = {
        h.fixture("titled-1.mkv"),
        "https://example.invalid/video/1",
        "https://example.invalid/video/2",
    },
}

h.wait_idle(function()
    append("https://example.invalid/video/3")
    h.wait_idle(function()
        h.expect_eq(h.count_log(log, "warn", WARNING), 1, "warnings while missing")
        for i = 1, 3 do
            h.expect_eq(h.title(i), nil, "title of index " .. i .. " while missing")
        end
        h.set_opts(nil, {"ytdl_hook-ytdl_path=" .. os.getenv("TP_TESTS") .. "/support/fake-yt-dlp"})
        append("https://example.invalid/video/4")
        h.wait_idle(function()
            h.expect_eq(h.title(1), "Remote 1", "title of index 1 once found")
            h.set_opts(nil, {"ytdl_hook-ytdl_path=tp-missing-exe-2"})
            append("https://example.invalid/video/5")
            h.wait_idle(function()
                h.expect_eq(h.count_log(log, "warn", WARNING), 2, "warnings after missing again")
                h.pass()
            end)
        end)
    end)
end)
