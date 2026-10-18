package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

h.setup{entries = {h.fixture("titled-1.mkv"), h.fixture("untitled.mkv")}}

h.wait_until("mpv titles the current entry", function()
    return h.title(0) == "Title 1"
end, 10, function()
    h.wait_until("title-prefetch is idle", function()
        return mp.get_property_native("user-data/title-prefetch/idle") == true
    end, 10, h.pass)
end)
