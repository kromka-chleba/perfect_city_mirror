--[[
    This is a part of "Perfect City".
    Copyright (C) 2025 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
local pcity_nodes = pcity_nodes

local pcc = pcity_common

pcity_nodes.door = {}
local door = pcity_nodes.door
door.__index = door

function door.new(args)
    local d = {}
    d.pos = args.pos
    d.orientation = args.orientation or "right" -- left or right doors
    d.open = args.open or false
    d.width = args.width or 2
    d.height = args.height or 4
    return setmetatable(d, door)
end

function door.check(d)
    return getmetatable(d) == door
end

function door:copy()
    return door.new({
            pos = self.pos and vector.copy(self.pos),
            orientation = self.orientation,
            open = self.open,
            width = self.width,
            height = self.height,
    })
end

function door:set_pos(pos)
    self.pos = pos
end

function door:get_dir()
    local rotation = math.pi / 2
    if self.orientation == "left" then
        rotation = -rotation
    end
    if self.open then
        return vector.rotate_around_axis(
            pcc.node_dir(self.pos),
            vector.new(0, 1, 0),
            rotation)
    end
    return pcc.node_dir(self.pos)
end

function door:barrier_positions()
    local positions = {}
    local rotation = vector.dir_to_rotation(self:get_dir())
    for x = 0, self.width - 1 do
        for y = 0, self.height - 1 do
            local p = vector.new(x, y, 0)
            if self.orientation == "left" then
                p.x = -p.x
            end
            table.insert(positions, vector.rotate(p, rotation) + self.pos)
        end
    end
    -- Remove the first position because the door node is there
    table.remove(positions, 1)
    core.log("error", dump(positions))
    return positions
end

function door:place_barrier()
    for _, t_pos in pairs(self:barrier_positions()) do
        local nodedef = pcc.get_nodedef(t_pos)
        if nodedef.buildable_to then
            core.set_node(t_pos, {name = pcc.node_name("door_barrier", mod_name),
                                  param2 = core.dir_to_fourdir(self:get_dir())})
        end
    end
end

function door:remove_barrier()
    for _, t_pos in pairs(self:barrier_positions()) do
        local node = core.get_node(t_pos)
        if node.name == pcc.node_name("door_barrier", mod_name) then
            core.remove_node(t_pos)
        end
    end
end
