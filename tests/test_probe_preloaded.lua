package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- Runs the probe the way `lib/local.lua` does,
-- except that `--really-quiet` becomes `--msg-level=all=v`.
-- At that level, mpv logs `Starting playback` only after it selected tracks
-- and set up decoders, which is the work the probe must skip
-- by answering from the `on_preloaded` hook.
local mpv = os.getenv("TP_MPV") --[[@as string]]
local root = os.getenv("TP_ROOT") --[[@as string]]

mp.command_native_async({
    name = "subprocess",
    playback_only = false,
    capture_stdout = true,
    capture_stderr = true,
    args = {
        mpv, "--no-config", "--load-scripts=no", "--idle=no", "--msg-level=all=v",
        "--vo=null", "--ao=null", "--pause", "--ytdl=no",
        "--script=" .. root .. "/title-prefetch/lib/probe.lua",
        "--", h.fixture("titled-1.mkv"),
    },
}, function(_, result)
    local stdout = result and result.stdout or ""
    local stderr = result and result.stderr or ""
    if not stdout:find('{"title":"Title 1"}', 1, true) then
        h.fail("probe did not report the title, stdout: " .. stdout)
        return
    end
    if stdout:find("Starting playback", 1, true) or stderr:find("Starting playback", 1, true) then
        h.fail("probe started playback before reporting the title")
        return
    end
    h.pass()
end)
