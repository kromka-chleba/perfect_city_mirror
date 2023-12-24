--[[
    This is a part of "Perfect City".
    Copyright (C) 2023 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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

minetest.register_node(
    mod_name..":lapm_1",
    {
        drawtype = "mesh",
        mesh = mod_name.."_lamp_1.obj",
        description = "Lamp 1",
        tiles = {{name = mod_name.."_lamp_1.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "wallmounted",
        light_source = 15,
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.35, 0.5},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.35, 0.5},
        },
    }
)

local plate_dimensions = "14x15"
local plate_top = "pcity_nodes_street_light_plate_top.png"
local plate_bottom = "pcity_nodes_street_light_plate_bottom.png"

minetest.register_node(
    mod_name..":concrete_pillar_bottom",
    {
        drawtype = "mesh",
        mesh = mod_name.."_concrete_pillar_bottom.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_concrete_pillar_bottom.png"..
                      "^[combine:"..plate_dimensions..":5,0="..plate_bottom}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":concrete_pillar_bottom_2",
    {
        drawtype = "mesh",
        mesh = mod_name.."_concrete_pillar_bottom_2.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_concrete_pillar_bottom.png"..
                      "^[combine:"..plate_dimensions..":5,17="..plate_top}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":concrete_pillar_thin",
    {
        drawtype = "mesh",
        mesh = mod_name.."_concrete_pillar_thin.obj",
        description = "Concrete pillar bottom",
        --tiles = {{name = mod_name.."_concrete_pillar_thin.png"}},
        tiles = {{name = mod_name.."_concrete_pillar_bottom.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":concrete_pillar_neck",
    {
        drawtype = "mesh",
        mesh = mod_name.."_concrete_pillar_neck.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_concrete_pillar_neck.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":street_light_ball",
    {
        drawtype = "mesh",
        mesh = mod_name.."_street_light_ball.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_street_light_ball_1.png"}},
        overlay_tiles = {{name = mod_name.."_street_light_ball_2.png"}},
        use_texture_alpha = "blend",
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":street_light_ball_lit",
    {
        drawtype = "mesh",
        mesh = mod_name.."_street_light_ball.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_street_light_ball_1_lit.png"}},
        overlay_tiles = {{name = mod_name.."_street_light_ball_2_lit.png"}},
        use_texture_alpha = "blend",
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        light_source = 15,
    }
)

minetest.register_node(
    mod_name..":plate_lamp",
    {
        drawtype = "mesh",
        mesh = mod_name.."_plate_lamp.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_plate_lamp_1.png"}},
        overlay_tiles = {{name = mod_name.."_plate_lamp_2.png"}},
        use_texture_alpha = "blend",
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":plate_lamp_lit",
    {
        drawtype = "mesh",
        mesh = mod_name.."_plate_lamp.obj",
        description = "Concrete pillar bottom",
        tiles = {{name = mod_name.."_plate_lamp_1_lit.png"}},
        overlay_tiles = {{name = mod_name.."_plate_lamp_2_lit.png"}},
        use_texture_alpha = "blend",
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        light_source = 15,
    }
)
