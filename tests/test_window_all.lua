package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local entries = {}
for n = 1, 15 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = -1}, entries = entries, pos = 0}

h.wait_until("every index is titled", function()
    for i = 0, 14 do
        if h.title(i) ~= "Title " .. (i + 1) then
            return false
        end
    end
    return true
end, 30, h.pass)
