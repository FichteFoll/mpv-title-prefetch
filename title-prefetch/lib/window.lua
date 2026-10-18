-- Copyright (c) 2026 FichteFoll <fichtefoll2@googlemail.com>
-- SPDX-License-Identifier: MIT

-- Which playlist indices lie around the current position. Pure; requires nothing from mpv.

local window = {}

---Return the 0-based indices within `range` of `pos`, nearest first,
---the next entry before the previous one on equal distance.
---`pos` itself is excluded, unless it is -1, in which case the window is centered on 0.
---@param count integer number of playlist entries
---@param pos integer current playlist position, or -1
---@param range integer maximum distance; negative = all, 0 = none
---@return integer[]
function window.indices(count, pos, range)
    ---@type integer[]
    local result = {}
    if range == 0 or count == 0 then
        return result
    end

    local center = pos
    if pos < 0 then
        center = 0
        result[1] = 0
    end
    local max_distance = range < 0 and count or range
    for distance = 1, max_distance do
        local next_index, prev_index = center + distance, center - distance
        if next_index >= count and prev_index < 0 then
            break
        end
        if next_index < count then
            result[#result + 1] = next_index
        end
        if prev_index >= 0 then
            result[#result + 1] = prev_index
        end
    end
    return result
end

return window
