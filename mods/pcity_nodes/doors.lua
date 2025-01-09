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

local barriers_visible = core.settings:get("pcity_barriers_visible") == "true"

local door_unit_box = {
    type = "fixed",
    fixed = {-0.5, -0.5, 0.0,
             0.5, 0.5, 0.2},
}

minetest.register_node(
    pcc.node_name("door_barrier", mod_name),
    {
        drawtype = barriers_visible and "nodebox" or "airlike",
        description = "Door barrier",
        groups = {cracky = 3},
        paramtype = "light",
        paramtype2 = "4dir",
        pointable = barriers_visible,
        use_texture_alpha = "clip",
        tiles = {
            {name = pcc.texture_name("barrier", mod_name)},
        },
        node_box = door_unit_box,
        selection_box = door_unit_box,
        collision_box = door_unit_box,
    }
)

local door_unit_box_open = {
    type = "fixed",
    fixed = {-0.5, -0.5, -0.5,
             -0.3, 0.5, 0.5},
}

minetest.register_node(
    pcc.node_name("door_barrier_open", mod_name),
    {
        drawtype = barriers_visible and "nodebox" or "airlike",
        description = "Door barrier open",
        groups = {cracky = 3},
        paramtype = "light",
        paramtype2 = "4dir",
        pointable = barriers_visible,
        use_texture_alpha = "clip",
        tiles = {
            {name = pcc.texture_name("barrier", mod_name)},
        },
        node_box = door_unit_box_open,
        selection_box = door_unit_box_open,
        collision_box = door_unit_box_open,
    }
)

local function door_template(name, description)
    return {
        drawtype = "mesh",
        mesh = mod_name.."_"..name..".obj",
        description = description,
        tiles = {
            {name = pcc.color_palette},
        },
        groups = {cracky = 3},
        paramtype = "light",
        paramtype2 = "4dir",
    }
end

local function register_doors(name, nodedef)
    nodedef.selection_box = door_unit_box
    nodedef.collision_box = door_unit_box
    minetest.register_node(mod_name..":"..name, nodedef)
end

local basic_doors = pcity_nodes.door.new({
        orientation = "right",
})

local basic_doors_open = pcity_nodes.door.new({
        orientation = "right",
        open = true,
})

minetest.register_node(
    pcc.node_name("doors_front_1", mod_name),
    {
        drawtype = "mesh",
        mesh = mod_name.."_doors_front_1.obj",
        description = "Doors Front 1",
        tiles = {
            {name = pcc.color_palette},
        },
        groups = {cracky = 3},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, 0.0,
                     1.5, 3.5, 0.2},
        },
        collision_box = door_unit_box,
        on_construct = function(pos)
            local door = basic_doors:copy()
            door:set_pos(pos)
            door:place_barrier()
        end,
        on_destruct = function(pos)
            local door = basic_doors:copy()
            door:set_pos(pos)
            door:remove_barrier()
        end,
        on_rotate = function(pos, node, user, mode, new_param2, ...)
            if core.is_protected(pos, user:get_player_name()) then
                return false
            end
            local door = basic_doors:copy()
            door:set_pos(pos)
            door:remove_barrier()
            node.param2 = new_param2 -- rotate
            core.swap_node(pos, node)
            door:place_barrier()
            return true
        end,
    }
)

minetest.register_node(
    mod_name..":doors_front_1_open",
    {
        drawtype = "mesh",
        mesh = mod_name.."_doors_front_1_open.obj",
        description = "Doors Front 1 Open",
        tiles = {
            {name = pcc.color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        collision_box = {
            type = "fixed",
            fixed = {0,0,0,
                     0,0,0},
        },
        on_construct = function(pos)
            local door = basic_doors_open:copy()
            door:set_pos(pos)
            door:place_barrier()
        end,
        on_destruct = function(pos)
            local door = basic_doors_open:copy()
            door:set_pos(pos)
            door:remove_barrier()
        end,
        on_rotate = function(pos, node, user, mode, new_param2, ...)
            if core.is_protected(pos, user:get_player_name()) then
                return false
            end
            local door = basic_doors_open:copy()
            door:set_pos(pos)
            door:remove_barrier()
            node.param2 = new_param2 -- rotate
            core.swap_node(pos, node)
            door:place_barrier()
            return true
        end,
    }
)
