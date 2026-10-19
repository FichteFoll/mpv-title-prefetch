package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local msg = require("mp.msg")
local utils = require("mp.utils")

-- A nested mpv with a normal config and the default `cache_dir`,
-- whose `~~cache` points into `TP_TMP` via `XDG_CACHE_HOME`.
local tmp = os.getenv("TP_TMP") --[[@as string]]
local mpv = os.getenv("TP_MPV") --[[@as string]]
local tests = os.getenv("TP_TESTS") --[[@as string]]
local marker = utils.join_path(tmp, "await-titles.done")
local cache_dir = utils.join_path(tmp, "xdg/mpv/title-prefetch")

---@param fn fun()
local function run_nested(fn)
    os.remove(marker)
    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stderr = true,
        env = {
            "TP_TMP=" .. tmp,
            "PATH=" .. os.getenv("PATH"),
            "HOME=" .. utils.join_path(tmp, "home"),
            "XDG_CACHE_HOME=" .. utils.join_path(tmp, "xdg"),
        },
        args = {
            mpv, "--idle=no", "--pause", "--vo=null", "--ao=null",
            "--msg-level=all=warn,title_prefetch=debug",
            "--script=" .. utils.join_path(os.getenv("TP_ROOT") --[[@as string]], "title-prefetch"),
            "--script=" .. utils.join_path(tests, "support/await-titles.lua"),
            "--script-opts=title-prefetch-mpv_path=" .. mpv
                .. ",ytdl_hook-ytdl_path=" .. utils.join_path(tests, "support/fake-yt-dlp")
                .. ",title-prefetch-range=1",
            "--", h.fixture("untitled.mkv"), "https://example.invalid/video/a",
        },
    }, function(_, result)
        local stderr = tostring(result and result.stderr)
        msg.info("nested mpv stderr:\n" .. stderr)
        if not utils.file_info(marker) then
            h.fail("the nested mpv did not title its entries, see its stderr above")
            return
        end
        fn()
    end)
end

-- The first instance is killed as soon as the title appears,
-- so the cache file exists only if it was written through.
run_nested(function()
    local names = utils.readdir(cache_dir, "files") or {}
    h.expect_eq(#names, 1, "files in " .. cache_dir)
    h.expect_eq(names[1] and names[1]:match("^%x+%.json$") ~= nil, true, "cache file name " .. tostring(names[1]))
    run_nested(function()
        h.expect_eq(h.count_calls("/video/a"), 1, "calls for /video/a")
        h.pass()
    end)
end)
