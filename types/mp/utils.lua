---@meta

local utils = {}

---Concatenate two paths; returns `p2` unchanged if it is absolute.
---@param p1 string
---@param p2 string
---@return string
function utils.join_path(p1, p2) end

---@class FileInfo
---@field mode integer
---@field size integer
---@field atime integer
---@field mtime integer
---@field ctime integer
---@field is_file boolean
---@field is_dir boolean

---@param path string
---@return FileInfo? info
---@return string? error
function utils.file_info(path) end

---@param str string
---@param trail? boolean
---@return any value
---@return string? error
---@return string? trail
function utils.parse_json(str, trail) end

---@param v any
---@return string? json
---@return string? error
function utils.format_json(v) end

return utils
