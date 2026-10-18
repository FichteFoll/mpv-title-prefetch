package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

h.setup{opts = {resolve_remote = false}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/a",
    "https://example.invalid/video/b",
}, pos = 0}

h.wait_idle(function()
    h.expect_eq(#h.ytdl_calls(), 0, "yt-dlp calls with resolve_remote=no")
    -- Disable `ytdl` first, so that no pass sees it enabled together with resolve_remote.
    mp.set_property("ytdl", "no")
    h.set_opts({resolve_remote = true})
    h.wait_idle(function()
        h.expect_eq(#h.ytdl_calls(), 0, "yt-dlp calls with ytdl=no")
        -- Positive control: the same setup resolves titles once `ytdl` is enabled.
        mp.set_property("ytdl", "yes")
        h.wait_until("index 1 is titled", function()
            return h.title(1) == "Remote a"
        end, 20, h.pass)
    end)
end)
