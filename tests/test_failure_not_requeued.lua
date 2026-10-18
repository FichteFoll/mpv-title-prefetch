package.path = os.getenv("TP_TESTS") .. "/support/?.lua;" .. package.path
local h = require("harness")

h.setup{opts = {cache_size = 0, range = 1}, entries = {
    h.fixture("titled-1.mkv"),
    h.fixture("untitled.mkv"),
}}

-- Without the failure set, the probe for untitled.mkv would be re-spawned forever,
-- and the plugin would never become idle.
-- The same as `h.wait_idle`, but with a shorter timeout.
mp.add_timeout(0.3, function()
    h.wait_until("title-prefetch is idle", function()
        return mp.get_property_native("user-data/title-prefetch/idle") == true
    end, 5, function()
        h.expect_eq(h.title(1), nil, "title of index 1")
        h.pass()
    end)
end)
