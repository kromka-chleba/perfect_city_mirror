--[[
    This is a part of "Perfect City".
    Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

-- Mock Minetest/Luanti API for standalone testing
-- This allows tests to run without requiring Minetest/Luanti installation

local M = {}

-- Mock vector library (Minetest vector functions)
-- Create a metatable for vectors that supports arithmetic operations
local vector_mt = {}
vector_mt.__add = function(a, b)
    if type(b) == "number" then
        return setmetatable({x = a.x + b, y = a.y + b, z = a.z + b}, getmetatable(a))
    else
        return setmetatable({x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}, getmetatable(a))
    end
end
vector_mt.__sub = function(a, b)
    if type(b) == "number" then
        return setmetatable({x = a.x - b, y = a.y - b, z = a.z - b}, getmetatable(a))
    else
        return setmetatable({x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}, getmetatable(a))
    end
end
vector_mt.__mul = function(a, b)
    if type(a) == "number" then
        return setmetatable({x = a * b.x, y = a * b.y, z = a * b.z}, getmetatable(b))
    elseif type(b) == "number" then
        return setmetatable({x = a.x * b, y = a.y * b, z = a.z * b}, getmetatable(a))
    else
        return setmetatable({x = a.x * b.x, y = a.y * b.y, z = a.z * b.z}, getmetatable(a))
    end
end
vector_mt.__div = function(a, b)
    if type(b) == "number" then
        return setmetatable({x = a.x / b, y = a.y / b, z = a.z / b}, getmetatable(a))
    else
        return setmetatable({x = a.x / b.x, y = a.y / b.y, z = a.z / b.z}, getmetatable(a))
    end
end
vector_mt.__unm = function(a)
    return setmetatable({x = -a.x, y = -a.y, z = -a.z}, getmetatable(a))
end

M.vector = {
    new = function(x, y, z)
        local v = {x = x or 0, y = y or 0, z = z or 0}
        return setmetatable(v, vector_mt)
    end,
    
    check = function(v)
        return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"
    end,
    
    copy = function(v)
        local cv = {x = v.x, y = v.y, z = v.z}
        return setmetatable(cv, vector_mt)
    end,
    
    equals = function(a, b)
        return a.x == b.x and a.y == b.y and a.z == b.z
    end,
    
    add = function(a, b)
        local v = M.vector.new(a.x + b.x, a.y + b.y, a.z + b.z)
        return v
    end,
    
    subtract = function(a, b)
        local v = M.vector.new(a.x - b.x, a.y - b.y, a.z - b.z)
        return v
    end,
    
    multiply = function(a, b)
        if type(b) == "number" then
            return M.vector.new(a.x * b, a.y * b, a.z * b)
        else
            return M.vector.new(a.x * b.x, a.y * b.y, a.z * b.z)
        end
    end,
    
    divide = function(a, b)
        if type(b) == "number" then
            return M.vector.new(a.x / b, a.y / b, a.z / b)
        else
            return M.vector.new(a.x / b.x, a.y / b.y, a.z / b.z)
        end
    end,
    
    distance = function(a, b)
        local dx = a.x - b.x
        local dy = a.y - b.y
        local dz = a.z - b.z
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    end,
    
    length = function(v)
        return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
    end,
    
    normalize = function(v)
        local len = M.vector.length(v)
        if len == 0 then
            return M.vector.new(0, 0, 0)
        end
        return M.vector.new(v.x / len, v.y / len, v.z / len)
    end,
    
    round = function(v)
        return M.vector.new(
            math.floor(v.x + 0.5),
            math.floor(v.y + 0.5),
            math.floor(v.z + 0.5)
        )
    end,
    
    floor = function(v)
        return M.vector.new(
            math.floor(v.x),
            math.floor(v.y),
            math.floor(v.z)
        )
    end,
    
    ceil = function(v)
        return M.vector.new(
            math.ceil(v.x),
            math.ceil(v.y),
            math.ceil(v.z)
        )
    end,
    
    dot = function(a, b)
        return a.x * b.x + a.y * b.y + a.z * b.z
    end,
    
    cross = function(a, b)
        return M.vector.new(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )
    end,
    
    offset = function(v, x, y, z)
        return M.vector.new(v.x + x, v.y + y, v.z + z)
    end,
    
    sort = function(a, b)
        return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))
    end,
    
    comparator = function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        elseif a.y ~= b.y then
            return a.y < b.y
        else
            return a.z < b.z
        end
    end,
    
    in_area = function(pos, min_pos, max_pos)
        return pos.x >= min_pos.x and pos.x <= max_pos.x
           and pos.y >= min_pos.y and pos.y <= max_pos.y
           and pos.z >= min_pos.z and pos.z <= max_pos.z
    end,
    
    angle = function(a, b)
        -- Calculate angle between two vectors using dot product
        local dot = M.vector.dot(a, b)
        local len_a = M.vector.length(a)
        local len_b = M.vector.length(b)
        if len_a == 0 or len_b == 0 then
            return 0
        end
        local cos_angle = dot / (len_a * len_b)
        -- Clamp to [-1, 1] to avoid floating point errors
        cos_angle = math.max(-1, math.min(1, cos_angle))
        return math.acos(cos_angle)
    end,
    
    sign = function(v)
        local function sign_value(x)
            if x > 0 then return 1
            elseif x < 0 then return -1
            else return 0
            end
        end
        return M.vector.new(sign_value(v.x), sign_value(v.y), sign_value(v.z))
    end,
    
    abs = function(v)
        return M.vector.new(math.abs(v.x), math.abs(v.y), math.abs(v.z))
    end,
    
    rotate = function(v, rot)
        -- Simple Y-axis rotation for the perpendicular calculation
        -- This is a simplified version - Minetest's rotate is more complex
        if rot.y ~= 0 then
            local cos_a = math.cos(rot.y)
            local sin_a = math.sin(rot.y)
            return M.vector.new(
                v.x * cos_a - v.z * sin_a,
                v.y,
                v.x * sin_a + v.z * cos_a
            )
        end
        return M.vector.copy(v)
    end,
}

-- Mock core/minetest API
M.core = {
    get_current_modname = function()
        return "pcity_mapgen"
    end,
    
    get_modpath = function(modname)
        -- Get the directory where this script is located
        local info = debug.getinfo(1, "S")
        local script_path = info.source:sub(2) -- Remove '@' prefix
        local tests_dir = script_path:match("(.*/)")
        -- Go up two levels from tests/mocks/ to get to pcity_mapgen/
        return tests_dir:gsub("/tests/mocks/$", "")
    end,
    
    settings = {
        get_bool = function(key)
            return true
        end
    }
}

-- Mock global functions used by the modules
_G.shallow_dump = function(value)
    if type(value) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(value) do
            if not first then result = result .. ", " end
            first = false
            result = result .. tostring(k) .. "=" .. tostring(v)
        end
        return result .. "}"
    else
        return tostring(value)
    end
end

return M
