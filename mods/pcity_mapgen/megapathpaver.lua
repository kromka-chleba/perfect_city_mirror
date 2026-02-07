--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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

local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")

pcmg.megapathpaver = {}
local megapathpaver = pcmg.megapathpaver
megapathpaver.__index = megapathpaver
megapathpaver.cache = {}

function megapathpaver.cache.new(c)
    local cache = c or {}
    if not cache.pathpavers then
        cache.pathpavers = {}
    end
    return cache
end

local function make_method(method)
    return function (self, ...)
        local products = {}
        local central_hash = pcmg.citychunk_hash(self.central.origin)
        products[central_hash] = method(self.central, ...)
        for _, neighbor in pairs(self.neighbors) do
            local hash = pcmg.citychunk_hash(neighbor.origin)
            products[hash] = method(neighbor, ...)
        end
        return products
    end
end

megapathpaver.__index = function(object, key)
    if megapathpaver[key] then
        object[key] = megapathpaver[key]
        return megapathpaver[key]
    elseif pcmg.pathpaver[key] then
        local method = make_method(pcmg.pathpaver[key])
        object[key] = method
        return method
    end
end

local function neighboring_pathpavers(citychunk_origin, cache)
    local neighbors = pcmg.citychunk_neighbors(citychunk_origin)
    local pathpavers = {}
    for _, origin in pairs(neighbors) do
        local hash = pcmg.citychunk_hash(origin)
        local pathpav = cache.pathpavers[hash] or pcmg.pathpaver.new(origin)
        cache.pathpavers[hash] = pathpav
        table.insert(pathpavers, pathpav)
    end
    return pathpavers
end

-- Rename to path store?
function megapathpaver.new(citychunk_origin, cache)
    local mpp = {}
    mpp.origin = vector.copy(citychunk_origin)
    mpp.cache = megapathpaver.cache.new(cache)
    local hash = pcmg.citychunk_hash(citychunk_origin)
    mpp.central = cache.pathpavers[hash] or pcmg.pathpaver.new(citychunk_origin)
    mpp.neighbors = neighboring_pathpavers(mpp.origin, cache)
    mpp.paths = mpp.central.paths
    return setmetatable(mpp, megapathpaver)
end

function megapathpaver:save_path(pth)
    self.central.paths[pth] = pth
    for _, pnt in pairs(pth:all_points()) do
        self:save_point(pnt)
    end
end

function megapathpaver.check(p)
    return getmetatable(p) == megapathpaver
end
