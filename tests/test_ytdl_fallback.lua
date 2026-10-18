package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- The first candidate cannot be started, so the entries that were tried with it
-- must be retried with the fake instead of being counted as failed.
local fake = os.getenv("TP_TESTS") .. "/support/fake-yt-dlp"
h.setup{
    opts = {concurrency = 1, range = -1},
    script_opts = {"ytdl_hook-ytdl_path=tp-missing-exe:" .. fake},
    entries = {
        h.fixture("titled-1.mkv"),
        "https://example.invalid/video/1",
        "https://example.invalid/video/2",
        "https://example.invalid/video/3",
    },
    pos = 0,
}

h.wait_until("indices 1-3 are titled", function()
    for i = 1, 3 do
        if h.title(i) ~= "Remote " .. i then
            return false
        end
    end
    return true
end, 20, function()
    h.wait_idle(h.pass)
end)
