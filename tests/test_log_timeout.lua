package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

local log = h.capture_log("debug")

h.setup{opts = {range = -1, timeout = 0.2}, entries = {
    h.fixture("titled-1.mkv"),
    "https://example.invalid/slow/1",
}}

h.wait_idle(function()
    h.expect_eq(h.count_log(log, "warn", "timed out after 0.2 s: https://example.invalid/slow/1"), 1,
        "timeout warnings")
    h.expect_eq(h.count_log(log, "v", "failed https://example.invalid/slow/1: aborted after the timeout"), 1,
        "failed lines")

    -- R2, R3: the timeout warning, the failure and the duration line share the id of the killed subprocess.
    local warn_id
    local warnings = 0
    for _, line in ipairs(log) do
        local id = line.level == "warn"
            and line.text:match("^%[#(%d+)%] timed out after 0%.2 s: https://example%.invalid/slow/1$")
        if id then
            warnings = warnings + 1
            warn_id = id
        end
    end
    h.expect_eq(warnings, 1, "prefixed timeout warnings")
    if not warn_id then
        return
    end
    h.expect_eq(
        h.count_log(log, "v", "[#" .. warn_id .. "] failed https://example.invalid/slow/1: aborted after the timeout"),
        1, "failed lines with the id of the warning")
    h.expect_eq(h.count_log(log, "v", "[#" .. warn_id .. "] finished after "), 1, "duration lines")
    h.expect_eq(h.title(1), nil, "title of index 1")
    h.pass()
end)
