---@meta
-- Handwritten definitions of the parts of the mpv Lua API that this project uses.
-- Source: DOCS/man/lua.rst of mpv.

---@class MpTimer
---@field timeout number
---@field oneshot boolean
local MpTimer = {}

---Disable the timer, remembering the elapsed time.
function MpTimer:stop() end

---Disable the timer and reset the elapsed time.
function MpTimer:kill() end

---Restart the timer.
function MpTimer:resume() end

---@return boolean
function MpTimer:is_enabled() end

---@class mp
mp = {}

---@param ... string|number|boolean
---@return true|nil success
---@return string? error
function mp.commandv(...) end

---@param t table
---@param def? any
---@return any result
---@return string? error
function mp.command_native(t, def) end

---@class MpAsyncCommand

---@param t table
---@param fn? fun(success: boolean, result: any, error: string?)
---@return MpAsyncCommand? request nil if starting the command failed
---@return string? error
function mp.command_native_async(t, fn) end

---@param t MpAsyncCommand
function mp.abort_async_command(t) end

---@param name string
---@param def? string
---@return string? value
---@return string? error
function mp.get_property(name, def) end

---@param name string
---@param def? boolean
---@return boolean? value
---@return string? error
function mp.get_property_bool(name, def) end

---@param name string
---@param def? any
---@return any value
---@return string? error
function mp.get_property_native(name, def) end

---@param name string
---@param def? number
---@return number? value
---@return string? error
function mp.get_property_number(name, def) end

---@param name string
---@param value string
---@return true|nil success
---@return string? error
function mp.set_property(name, value) end

---@param name string
---@param value number
---@return true|nil success
---@return string? error
function mp.set_property_number(name, value) end

---@param name string
---@param value any
---@return true|nil success
---@return string? error
function mp.set_property_native(name, value) end

---@return number
function mp.get_time() end

---@param level string
function mp.enable_messages(level) end

---@param name string
---@param fn fun(event: table)
function mp.register_event(name, fn) end

---@param name string
---@param fn fun(...: string)
function mp.register_script_message(name, fn) end

---@param seconds number
---@param fn fun()
---@param disabled? boolean
---@return MpTimer
function mp.add_timeout(seconds, fn, disabled) end

---@param seconds number
---@param fn fun()
---@param disabled? boolean
---@return MpTimer
function mp.add_periodic_timer(seconds, fn, disabled) end

---@param name string
---@param type? "none"|"native"|"bool"|"string"|"number"
---@param fn fun(name: string, value: any)
function mp.observe_property(name, type, fn) end

---@param fn fun(name: string, value: any) a function passed to `mp.observe_property`
function mp.unobserve_property(fn) end

---@return string? directory nil for a single-file script
function mp.get_script_directory() end

---@param filename string
---@return string? path nil if the file is not found in any config directory
function mp.find_config_file(filename) end
