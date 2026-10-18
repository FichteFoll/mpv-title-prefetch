package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")
local utils = require("mp.utils")

---@param src string
---@param dst string
local function copy_file(src, dst)
    local input = assert(io.open(src, "rb"))
    local data = input:read("*a")
    input:close()
    local output = assert(io.open(dst, "wb"))
    output:write(data)
    output:close()
end

local mutable = utils.join_path(os.getenv("TP_TMP") --[[@as string]], "mutable.mkv")
copy_file(h.fixture("titled-1.mkv"), mutable)

h.setup{opts = {range = 1}, entries = {h.fixture("titled-2.mkv"), mutable}, pos = 0}

-- The plugin handles the same event, so this tells when it can have refreshed its cache.
local loaded_pos = -1
mp.register_event("file-loaded", function()
    loaded_pos = mp.get_property_number("playlist-playing-pos", -1) --[[@as integer]]
end)

-- Playing the file without a title must drop its cached `Title 3`.
local function expect_untitled_after_playback()
    copy_file(h.fixture("untitled.mkv"), mutable)
    mp.set_property_number("playlist-pos", 2)
    h.wait_until("index 2 was loaded", function()
        return loaded_pos == 2
    end, 20, function()
        h.wait_idle(function()
            mp.commandv("loadfile", mutable, "append")
            h.wait_idle(function()
                h.expect_eq(h.title(3), nil, "title of index 3")
                h.pass()
            end)
        end)
    end)
end

h.wait_until("index 1 is titled", function()
    return h.title(1) == "Title 1"
end, 20, function()
    copy_file(h.fixture("titled-3.mkv"), mutable)
    mp.set_property_number("playlist-pos", 1)
    h.wait_until("index 1 plays with its new title", function()
        return mp.get_property_number("playlist-playing-pos") == 1
            and mp.get_property("media-title") == "Title 3"
    end, 20, function()
        h.expect_eq(h.title(1), "Title 1", "kept title of index 1")
        -- `media-title` can change before the plugin has handled `file-loaded`.
        h.wait_idle(function()
            mp.commandv("loadfile", mutable, "append")
            h.wait_until("index 2 is titled", function()
                return h.title(2) ~= nil
            end, 20, function()
                h.expect_eq(h.title(2), "Title 3", "title of index 2")
                expect_untitled_after_playback()
            end)
        end)
    end)
end)
