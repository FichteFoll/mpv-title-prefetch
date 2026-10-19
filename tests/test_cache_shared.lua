package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local msg = require("mp.msg")
local utils = require("mp.utils")

-- A nested mpv shares the cache directory of this instance.
local tmp = os.getenv("TP_TMP") --[[@as string]]
local mpv = os.getenv("TP_MPV") --[[@as string]]
local tests = os.getenv("TP_TESTS") --[[@as string]]
local marker = utils.join_path(tmp, "await-titles.done")

local function url(id)
    return "https://example.invalid/video/" .. id
end

---@param fn fun()
local function run_nested(fn)
    os.remove(marker)
    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stderr = true,
        env = {"TP_TMP=" .. tmp, "PATH=" .. os.getenv("PATH")},
        args = {
            mpv, "--no-config", "--idle=no", "--pause", "--vo=null", "--ao=null",
            "--msg-level=all=warn,title_prefetch=debug",
            "--script=" .. utils.join_path(os.getenv("TP_ROOT") --[[@as string]], "title-prefetch"),
            "--script=" .. utils.join_path(tests, "support/await-titles.lua"),
            "--script-opts=title-prefetch-mpv_path=" .. mpv
                .. ",ytdl_hook-ytdl_path=" .. utils.join_path(tests, "support/fake-yt-dlp")
                .. ",title-prefetch-range=2,title-prefetch-cache_dir=" .. utils.join_path(tmp, "cache"),
            "--", h.fixture("untitled.mkv"), url("a"), url("b"),
        },
    }, function(_, result)
        msg.info("nested mpv stderr:\n" .. tostring(result and result.stderr))
        if not utils.file_info(marker) then
            h.fail("the nested mpv did not title its entries, see its stderr above")
            return
        end
        fn()
    end)
end

h.setup{opts = {range = -1}, entries = {h.fixture("untitled.mkv"), url("a")}}

h.wait_until("index 1 is titled", function()
    return h.title(1) == "Remote a"
end, 20, function()
    h.wait_idle(function()
        -- The nested instance finds a in the cache this instance wrote.
        run_nested(function()
            h.expect_eq(h.count_calls("/video/a"), 1, "calls for /video/a")
            h.expect_eq(h.count_calls("/video/b"), 1, "calls for /video/b")
            -- This instance finds b in the cache the nested instance wrote.
            mp.commandv("loadfile", url("b"), "append")
            h.wait_until("index 2 is titled", function()
                return h.title(2) == "Remote b"
            end, 20, function()
                h.wait_idle(function()
                    h.expect_eq(h.count_calls("/video/b"), 1, "calls for /video/b after appending it")
                    h.pass()
                end)
            end)
        end)
    end)
end)
