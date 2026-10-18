---@meta

local options = {}

---Overwrite the values of `table` with those from the config file and `script-opts`.
---@param table table<string, string|number|boolean>
---@param identifier? string defaults to `mp.get_script_name()`
---@param on_update? fun(list: table<string, true>) called with the changed keys on runtime updates
function options.read_options(table, identifier, on_update) end

return options
