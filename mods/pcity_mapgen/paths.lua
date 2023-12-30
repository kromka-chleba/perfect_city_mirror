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
local mlib = dofile(mod_path.."/mlib.lua")
local vector = vector
local pcmg = pcity_mapgen
pcmg.path = {}
local path = pcmg.path

local path_metatable = {}

local allowed_keys = {
    start = true,
    segments = true,
}

function path.length(pth)
    local sum = 0
    for _, segment in pairs(pth.segments) do
        sum = sum + vector.length(segment)
    end
    return sum
end

function path.finish(pth)
    local finish = pth.start
    for _, segment in ipairs(pth.segments) do
        finish = vector.add(finish, segment)
    end
    return finish
end

function path.points(pth)
    local points = {pth.start}
    local current_point = pth.start
    for _, segment in ipairs(pth.segments) do
        current_point = vector.add(current_point, segment)
        table.insert(points, current_point)
    end
    return points
end

local function validate_input(start, segments)
    assert(vector.check(start), "Start \'"..dump(start).."\' is not a vector!")
    for _, segment in ipairs(segments) do
        assert(vector.check(segment),
               "Segment \'"..dump(segment).."\' is not a vector!")
    end
end

-- fires when pth[key] is nil
function path_metatable.__index(pth, key)
    if key == "finish" then
        local finish = path.finish(pth)
        rawset(pth, key, finish)
        return finish
    end
    return rawget(pth, key)
end

function path_metatable.__newindex(pth, key, value)
    if allowed_keys[key] then
        rawset(pth, key, value)
    else
        assert(false, "Key \'"..key.."\' is not supported by the path type!")
    end
end

function path_metatable.__concat(p1, p2)
    assert(p1.__type == "path" and
           p2.__type == "path",
           "p2: \'"..dump(p2).."\' is not a path!"
    )
    local new_segments = {}
    for _, segment in ipairs(p1.segments) do
        table.insert(new_segments, vector.new(segment))
    end
    for _, segment in ipairs(p2.segments) do
        table.insert(new_segments, vector.new(segment))
    end
    return path.new(vector.copy(p1.start), new_segments)
end

local function points_to_segments(points)
    local segments = {}
    for i = 1, #points - 1 do
        local vec = vector.subtract(points[i + 1], points[i])
        table.insert(segments, vec)
    end
    return segments
end

-- Can take either start + segments or points
function path.new(start, segments)
    local pth = setmetatable({["__type"] = "path"}, path_metatable)
    if type(start) == "table" and not segments then
        -- got a table of points
        validate_input(start[1], start)
        pth.start = start[1]
        pth.segments = points_to_segments(start)
    else
        -- got start and segments
        validate_input(start, segments)
        pth.start = start
        pth.segments = segments
    end
    -- users shouldn't change finish because it is automatically calculated
    rawset(pth, "finish", path.finish(pth))
    return pth
end

-- divides a path into smaller segments and returns points
-- along the path including start and stop
local function sample_path(path, sample_size)
    local segments = {}
    for _, segment in ipairs(path.segments) do
        local length = vector.length(segment)
        local nr = math.floor(length / sample_size)
        local new_segments = vector.split(segment, nr)
        for _, new_segment in ipairs(new_segments) do
            table.insert(segments, new_segment)
        end
    end
    local new_path = path.new(path.start)
    return path.points(new_path)
end
