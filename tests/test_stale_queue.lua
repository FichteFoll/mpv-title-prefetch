package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

-- Index 0 and 9 are local, all others are slow remote entries named after their index.
local entries = {}
for i = 0, 18 do
    if i == 0 then
        entries[#entries + 1] = h.fixture("titled-1.mkv")
    elseif i == 9 then
        entries[#entries + 1] = h.fixture("titled-2.mkv")
    else
        entries[#entries + 1] = "https://example.invalid/slow/" .. i
    end
end
-- `ytdl_batch_size = 1` keeps one URL per start, so that pending jobs can be dropped individually.
h.setup{opts = {range = 3, concurrency = 1, ytdl_batch_size = 1}, entries = entries, pos = 0}

local function window_titled()
    for _, i in ipairs({6, 7, 8, 10, 11, 12}) do
        if h.title(i) ~= "Slow " .. i then
            return false
        end
    end
    return true
end

-- Before the position changes, only slow/1 to slow/3 are in the window,
-- so "slow/1" cannot match slow/10 and later here.
h.wait_until("slow/1 was started", function()
    return h.count_calls("slow/1") > 0
end, 20, function()
    mp.set_property_number("playlist-pos", 9)
    h.wait_until("indices 6-8 and 10-12 are titled", window_titled, 20, function()
        h.expect_eq(h.count_calls("slow/2"), 0, "calls for the dropped slow/2")
        h.expect_eq(h.count_calls("slow/3"), 0, "calls for the dropped slow/3")
        -- slow/1 was already running when it left the window, so its result is still used.
        h.wait_until("index 1 is titled", function()
            return h.title(1) == "Slow 1"
        end, 20, h.pass)
    end)
end)
