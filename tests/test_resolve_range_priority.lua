package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local function resolve_range(...)
    mp.commandv("script-message-to", "title_prefetch", "resolve-range", ...)
end

-- Index 0 is local, all others are slow remote entries named after their index.
local entries = {h.fixture("titled-1.mkv")}
for i = 1, 12 do
    entries[#entries + 1] = "https://example.invalid/slow/" .. i
end
-- The window is index 1, then index 2.
-- `ytdl_batch_size = 1` keeps one URL per start, so that the order of single starts is observed.
h.setup{opts = {range = 2, concurrency = 1, ytdl_batch_size = 1}, entries = entries, pos = 0}

---@param indices integer[]
---@return boolean
local function all_titled(indices)
    for _, i in ipairs(indices) do
        if h.title(i) ~= "Slow " .. i then
            return false
        end
    end
    return true
end

h.wait_until("a resolver was started", function()
    return #h.ytdl_calls() > 0
end, 20, function()
    -- slow/1 runs for 0.5 s, and `concurrency = 1` keeps every other job pending,
    -- so both requests are in place before the next job starts.
    resolve_range("5", "6")
    resolve_range("9", "10")
    h.wait_until("indices 1, 2, 5, 6, 9 and 10 are titled", function()
        return all_titled({1, 2, 5, 6, 9, 10})
    end, 20, function()
        h.wait_idle(function()
            local ids = {}
            for _, line in ipairs(h.ytdl_calls()) do
                ids[#ids + 1] = line:match("/slow/(%d+)$")
            end
            -- slow/1 was already running.
            -- Then the latest request (R6), then the earlier one, which was not dropped (R6),
            -- and only then the rest of the window (R5).
            h.expect_eq(table.concat(ids, ","), "1,9,10,5,6,2", "resolution order")
            for _, i in ipairs({3, 4, 7, 8, 11, 12}) do
                h.expect_eq(h.title(i), nil, "title of index " .. i)
            end
            h.pass()
        end)
    end)
end)
