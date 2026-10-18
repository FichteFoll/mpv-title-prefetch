package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

-- The executable that ytdl_hook published is preferred over its `ytdl_path` option,
-- which the harness points at the fake.
local hook_exe = utils.join_path(os.getenv("TP_TMP") --[[@as string]], "hook-yt-dlp")
local f = assert(io.open(hook_exe, "w"))
f:write('#!/bin/sh\nfor url; do :; done\nprintf \'{"title":"Hook %s"}\\n\' "${url##*/}"\n')
f:close()
os.execute("chmod +x '" .. hook_exe .. "'")
mp.set_property_native("user-data/mpv/ytdl/path", hook_exe)

h.setup{opts = {range = 1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/a",
}}

h.wait_until("index 1 is titled", function()
    return h.title(1) ~= nil
end, 20, function()
    h.expect_eq(h.title(1), "Hook a", "title of index 1")
    h.expect_eq(#h.ytdl_calls(), 0, "calls of the fake from `ytdl_path`")
    h.wait_idle(h.pass)
end)
