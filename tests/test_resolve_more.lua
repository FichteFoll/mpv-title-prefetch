package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local function resolve_more(arg)
    mp.commandv("script-message-to", "title_prefetch", "resolve-more", arg)
end

local entries = {}
for n = 1, 10 do
    entries[#entries + 1] = h.fixture("titled-" .. n .. ".mkv")
end
h.setup{opts = {range = 1}, entries = entries, pos = 0}

h.wait_until("index 1 is titled", function()
    return h.title(1) == "Title 2"
end, 20, function()
    h.wait_idle(function()
        h.expect_eq(h.title(2), nil, "title of index 2 before resolve-more")
        resolve_more("2")
        h.wait_until("indices 2 and 3 are titled", function()
            return h.title(2) == "Title 3" and h.title(3) == "Title 4"
        end, 20, function()
            h.wait_idle(function()
                h.expect_eq(h.title(4), nil, "title of index 4 after resolve-more 2")
                resolve_more("all")
                h.wait_until("index 9 is titled", function()
                    return h.title(9) == "Title 10"
                end, 20, function()
                    resolve_more("bogus")
                    h.wait_idle(h.pass)
                end)
            end)
        end)
    end)
end)
