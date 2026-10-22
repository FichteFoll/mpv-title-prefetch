package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- Only the prefix of the built-in value is matched,
-- so that it stays written down in `lib/ytdl.lua` alone.
local DEFAULT_PREFIX = "--extractor-args youtube:player_skip"

---Append `url` to force another pass after an option change.
---@param url string
local function append(url)
    mp.commandv("loadfile", url, "append")
end

---@param url_part string plain substring
---@return string? line the only fake yt-dlp call containing `url_part`
local function call_for(url_part)
    local found
    for _, line in ipairs(h.ytdl_calls()) do
        if line:find(url_part, 1, true) then
            if found then
                h.fail("several calls for " .. url_part)
                return nil
            end
            found = line
        end
    end
    if not found then
        h.fail("no call for " .. url_part)
    end
    return found
end

---@param line string
---@param pattern string plain substring
---@param label string
local function expect_contains(line, pattern, label)
    if not line:find(pattern, 1, true) then
        h.fail(string.format("%s: expected %q in %q", label, pattern, line))
    end
end

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/video/1",
}}

h.wait_idle(function()
    h.expect_eq(h.count_calls("-J --ignore-no-formats-error --extractor-args youtube:"), 1,
        "calls with the default extractor args")

    h.set_opts{ytdl_extractor_args = "generic:impersonate default"}
    append("https://example.invalid/video/2")
    h.wait_idle(function()
        local line = call_for("/video/2")
        if not line then return end
        expect_contains(line, "--extractor-args generic:impersonate --extractor-args youtube:",
            "default expanded in place")

        h.set_opts{ytdl_extractor_args = ""}
        append("https://example.invalid/video/3")
        h.wait_idle(function()
            line = call_for("/video/3")
            if not line then return end
            expect_contains(line, "--ignore-no-formats-error --", "empty value")
            h.expect_eq(line:find("--extractor-args", 1, true), nil, "extractor args for an empty value")

            mp.set_property_native("ytdl-raw-options", {["extractor-args"] = "youtube:x=y"})
            h.set_opts{ytdl_extractor_args = "default"}
            append("https://example.invalid/video/4")
            h.wait_idle(function()
                line = call_for("/video/4")
                if not line then return end
                local default_at = line:find(DEFAULT_PREFIX, 1, true)
                local raw_at = line:find("--extractor-args youtube:x=y --", 1, true)
                if not (default_at and raw_at and default_at < raw_at) then
                    h.fail("raw extractor args do not follow the default ones: " .. line)
                    return
                end
                h.pass()
            end)
        end)
    end)
end)
