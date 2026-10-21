package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

local URL = "https://example.invalid/"

h.setup{opts = {range = -1}, entries = {
    h.fixture("titled-1.mkv"),
    URL .. "video/1",
    URL .. "video/2",
    URL .. "fail/3",
    URL .. "video/4",
    URL .. "video/5",
    URL .. "video/6",
    URL .. "video/7",
}}

---@param invocation string
---@return string urls the arguments after `--`
local function urls_of(invocation)
    return invocation:match(" %-%- (.*)$") or ""
end

local function remote_titled()
    for _, i in ipairs({1, 2, 4, 5, 6, 7}) do
        if h.title(i) ~= "Remote " .. i then
            return false
        end
    end
    return true
end

h.wait_until("all video entries are titled", remote_titled, 20, function()
    h.wait_idle(function()
        local invocations = h.ytdl_invocations()
        h.expect_eq(#invocations, 2, "invocations")
        -- Both batches start in the same pass, so their order in the log is not fixed.
        local first, second = invocations[1], invocations[2] or ""
        if not first:find("/video/1", 1, true) then
            first, second = second, first
        end
        h.expect_eq(urls_of(first), table.concat({
            URL .. "video/1", URL .. "video/2", URL .. "fail/3", URL .. "video/4", URL .. "video/5",
        }, " "), "URLs of the first batch")
        h.expect_eq(urls_of(second), URL .. "video/6 " .. URL .. "video/7", "URLs of the second batch")
        -- All entries of a batch show the same subprocess count.
        h.expect_eq(h.count_log(log, "debug", " (1/5)"), 5, "starts at (1/5)")
        h.expect_eq(h.count_log(log, "debug", " (2/5)"), 2, "starts at (2/5)")
        h.expect_eq(h.title(3), nil, "title of index 3")
        h.expect_eq(h.count_log(log, "v",
            "failed " .. URL .. "fail/3: exit status 1: ERROR: [generic] 3: Unable to download webpage"),
            1, "failed lines")

        -- A batch size below 1 means 1.
        h.set_opts{ytdl_batch_size = 0}
        mp.commandv("loadfile", URL .. "video/8", "append")
        mp.commandv("loadfile", URL .. "video/9", "append")
        h.wait_idle(function()
            invocations = h.ytdl_invocations()
            h.expect_eq(#invocations, 4, "invocations after disabling batching")
            local singles = {}
            for i = 3, #invocations do
                singles[#singles + 1] = urls_of(invocations[i])
            end
            table.sort(singles)
            h.expect_eq(table.concat(singles, ","), URL .. "video/8," .. URL .. "video/9",
                "URLs of the unbatched invocations")
            h.expect_eq(h.title(8), "Remote 8", "title of index 8")
            h.expect_eq(h.title(9), "Remote 9", "title of index 9")
            h.pass()
        end)
    end)
end)
