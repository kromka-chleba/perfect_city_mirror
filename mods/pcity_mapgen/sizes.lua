--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    SPDX-License-Identifier: AGPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

--[[
    DEPRECATED: This file is kept for backward compatibility.
    
    The sizes table is now part of the units module.
    Please use: local units = dofile(mod_path.."/units.lua")
    Then access:
      - Unit conversion functions directly on units
      - Size constants as units.sizes
    
    This file will be removed in a future version.
--]]

local mod_path = core.get_modpath("pcity_mapgen")

-- Load the units module which contains sizes
local units = dofile(mod_path.."/units.lua")

-- For backward compatibility, create a wrapper table that:
-- 1. Has all the size properties from units.sizes
-- 2. Has a .units property that points to the units module
local sizes_wrapper = {}

-- Set up metatable to forward reads to units.sizes
local wrapper_mt = {
    __index = function(t, k)
        if k == "units" then
            -- Return the units module for backward compatibility
            return units
        else
            -- Forward to units.sizes for size constants
            return units.sizes[k]
        end
    end,
    __newindex = function(t, k, v)
        error("Attempt to modify read-only sizes table (key: " .. tostring(k) .. ")", 2)
    end,
    __metatable = false  -- Hide the metatable
}

setmetatable(sizes_wrapper, wrapper_mt)

return sizes_wrapper
