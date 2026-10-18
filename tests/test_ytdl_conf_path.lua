package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local msg = require("mp.msg")
local utils = require("mp.utils")

-- `ytdl_path=` from `script-opts/ytdl_hook.conf` is used
-- when `script-opts` has no `ytdl_hook-ytdl_path`.
-- `run.sh` passes `--no-config`, which makes `mp.find_config_file` find nothing,
-- so the plugin runs in a nested mpv with its own config directory and no harness options.
local tmp = os.getenv("TP_TMP") --[[@as string]]
local mpv = os.getenv("TP_MPV") --[[@as string]]

local function write_file(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

local conf_exe = utils.join_path(tmp, "conf-yt-dlp")
write_file(conf_exe, '#!/bin/sh\nprintf \'conf %s\\n\' "$*" >> "$TP_TMP/ytdl.log"\n'
    .. 'printf \'{"title":"Conf"}\\n\'\n')
local config_dir = utils.join_path(tmp, "config")
-- An empty PATH keeps the default candidates, and so the real yt-dlp, out of reach.
local empty_bin = utils.join_path(tmp, "empty-bin")
os.execute("chmod +x '" .. conf_exe .. "' && mkdir -p '" .. config_dir .. "/script-opts' '" .. empty_bin .. "'")
write_file(utils.join_path(config_dir, "script-opts/ytdl_hook.conf"), "ytdl_path=" .. conf_exe .. "\n")

local url = "https://example.invalid/video/a"
local nested = mp.command_native_async({
    name = "subprocess",
    playback_only = false,
    capture_stderr = true,
    env = {"TP_TMP=" .. tmp, "PATH=" .. empty_bin},
    args = {
        mpv, "--config-dir=" .. config_dir, "--idle=no", "--pause", "--vo=null", "--ao=null",
        "--msg-level=all=warn,title_prefetch=debug",
        "--script=" .. utils.join_path(os.getenv("TP_ROOT") --[[@as string]], "title-prefetch"),
        "--script-opts=title-prefetch-range=1,title-prefetch-mpv_path=" .. mpv,
        "--", h.fixture("titled-1.mkv"), url,
    },
}, function(_, result)
    msg.info("nested mpv stderr:\n" .. tostring(result and result.stderr))
end)

h.wait_until("the nested plugin ran a yt-dlp candidate", function()
    return #h.ytdl_calls() > 0
end, 20, function()
    if nested then
        mp.abort_async_command(nested)
    end
    h.expect_eq(h.count_calls("conf "), #h.ytdl_calls(), "calls of the executable from ytdl_hook.conf")
    h.expect_eq(h.count_calls("-- " .. url), 1, "calls for " .. url)
    h.pass()
end)
