-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- The title of the loaded file, as mpv derives it apart from the filename.
-- Mirrors `mp_find_non_filename_media_title` in mpv's `player/misc.c`.

local media_title = {}

-- `metadata/by-key/` matches keys case-insensitively, like mpv itself.
local METADATA_KEYS = {"service_name", "title", "icy-title"}

---@return string? title nil when the file has none
function media_title.current()
    local forced = mp.get_property("force-media-title", "")
    if forced and forced ~= "" then
        return forced
    end
    for _, key in ipairs(METADATA_KEYS) do
        local value = mp.get_property("metadata/by-key/" .. key)
        if value and value ~= "" then
            return value
        end
    end
    return nil
end

return media_title
