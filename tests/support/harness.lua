-- Helpers for test driver scripts, which `tests/run.sh` runs inside mpv.

local msg = require("mp.msg")
local utils = require("mp.utils")

local h = {}

---@param name string
---@return string
local function env(name)
    local value = os.getenv(name)
    if not value then
        error("environment variable " .. name .. " is not set; run the tests via tests/run.sh")
    end
    return value
end

---@alias OptValue string|number|boolean

---@type table<string, OptValue>
local remembered_opts = {}
---@type string[]
local remembered_script_opts = {}
local finished = false

---@param name string
---@return string path absolute path of the fixture
function h.fixture(name)
    return utils.join_path(env("TP_FIXTURES"), name)
end

---@param value OptValue
---@return string
local function format_opt(value)
    if type(value) == "boolean" then
        return value and "yes" or "no"
    end
    return tostring(value)
end

---@param opts? table<string, OptValue>
---@param script_opts? string[]
local function remember_opts(opts, script_opts)
    for key, value in pairs(opts or {}) do
        remembered_opts[key] = value
    end
    remembered_script_opts = script_opts or remembered_script_opts
end

---Write the remembered options to `script-opts`, with `overrides` applied on top.
---@param overrides? table<string, OptValue> written, but not remembered
local function write_opts(overrides)
    ---@type table<string, string>
    local all = {}
    for key, value in pairs(remembered_opts) do
        all["title-prefetch-" .. key] = format_opt(value)
    end
    for key, value in pairs(overrides or {}) do
        all["title-prefetch-" .. key] = format_opt(value)
    end
    for _, entry in ipairs(remembered_script_opts) do
        local key, value = entry:match("^([^=]+)=(.*)$")
        if not key then
            h.fail("invalid script-opts entry: " .. entry)
            return
        end
        all[key] = value
    end
    all["title-prefetch-mpv_path"] = env("TP_MPV")
    mp.set_property_native("script-opts", all)
end

---Replace the whole `script-opts` property.
---Omitted arguments keep their remembered values; `opts` is merged into them.
---@param opts? table<string, OptValue> `title-prefetch` options
---@param script_opts? string[] extra raw `key=value` entries
function h.set_opts(opts, script_opts)
    remember_opts(opts, script_opts)
    write_opts()
end

---@class SetupArgs
---@field opts? table<string, OptValue>
---@field script_opts? string[]
---@field entries? string[] appended with `loadfile <entry> append`
---@field list? string appended with `loadlist <list> append`, instead of `entries`
---@field pos? integer defaults to 0

---Configure options, fill the playlist and start playback, synchronously.
---@param args SetupArgs
function h.setup(args)
    -- The plugin runs concurrently and reads `playlist-pos` live in its passes,
    -- so it must not resolve anything before the position below is final.
    -- `run.sh` starts it with `range=0`, this write keeps that,
    -- and only the write at the end applies the requested range.
    remember_opts(args.opts, args.script_opts)
    write_opts({range = 0})
    if args.list then
        mp.commandv("loadlist", args.list, "append")
    else
        for _, entry in ipairs(args.entries or {}) do
            mp.commandv("loadfile", entry, "append")
        end
    end
    local pos = args.pos or 0
    mp.set_property_number("playlist-pos", pos)
    if mp.get_property_bool("idle-active") then
        mp.commandv("playlist-play-index", pos)
    end
    h.set_opts()
end

---@param i integer
---@return string? title nil when unset
function h.title(i)
    return (mp.get_property("playlist/" .. i .. "/title"))
end

---Poll `pred` every 0.05 s and call `fn` once it returns true.
---@param desc string
---@param pred fun(): boolean
---@param timeout_s number
---@param fn fun()
function h.wait_until(desc, pred, timeout_s, fn)
    local deadline = mp.get_time() + timeout_s
    local timer
    timer = mp.add_periodic_timer(0.05, function()
        if finished then
            timer:kill()
        elseif pred() then
            timer:kill()
            fn()
        elseif mp.get_time() > deadline then
            timer:kill()
            h.fail("timeout: " .. desc)
        end
    end)
end

---Wait at least 0.3 s, so that the plugin can react to preceding changes,
---and then until `user-data/title-prefetch/idle` is true.
---@param fn fun()
function h.wait_idle(fn)
    mp.add_timeout(0.3, function()
        h.wait_until("title-prefetch is idle", function()
            return mp.get_property_native("user-data/title-prefetch/idle") == true
        end, 20, fn)
    end)
end

---@param actual any
---@param expected any
---@param label string
function h.expect_eq(actual, expected, label)
    if actual ~= expected then
        h.fail(string.format("%s: expected %q, got %q", label, tostring(expected), tostring(actual)))
    end
end

function h.pass()
    -- The first verdict wins, so that a failure cannot be overridden by a later pass.
    if finished then
        return
    end
    finished = true
    msg.info("PASS")
    mp.commandv("quit", 0)
end

---@param m string
function h.fail(m)
    if finished then
        return
    end
    finished = true
    msg.error(m)
    mp.commandv("quit", 1)
end

return h
