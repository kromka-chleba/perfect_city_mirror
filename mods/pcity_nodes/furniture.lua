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

local color_palette = "pcity_common_palette.png"

minetest.register_node(
    mod_name..":chair",
    {
        drawtype = "mesh",
        mesh = mod_name.."_chair.obj",
        description = "Chair",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)

minetest.register_node(
    mod_name..":table_corner",
    {
        drawtype = "mesh",
        mesh = mod_name.."_table_corner.obj",
        description = "Table Corner",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)

minetest.register_node(
    mod_name..":table_edge",
    {
        drawtype = "mesh",
        mesh = mod_name.."_table_edge.obj",
        description = "Table Edge",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)

minetest.register_node(
    mod_name..":table_middle",
    {
        drawtype = "mesh",
        mesh = mod_name.."_table_middle.obj",
        description = "Table Middle",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":shelf_1_left",
    {
        drawtype = "mesh",
        mesh = mod_name.."_shelf_1_left.obj",
        description = "Shelf 1 Left",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)

minetest.register_node(
    mod_name..":shelf_1_middle",
    {
        drawtype = "mesh",
        mesh = mod_name.."_shelf_1_middle.obj",
        description = "Shelf 1 Middle",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)

minetest.register_node(
    mod_name..":shelf_1_right",
    {
        drawtype = "mesh",
        mesh = mod_name.."_shelf_1_right.obj",
        description = "Shelf 1 Right",
        tiles = {
            {name = color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
    }
)
