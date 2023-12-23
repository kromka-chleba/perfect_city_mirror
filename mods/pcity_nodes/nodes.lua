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

-- Pierwszego dnia bóg stworzył beton
minetest.register_node(
    mod_name..":concrete",
    {
        description = "Concrete",
        tiles = {{name = mod_name.."_concrete.png",
                  align_style = "world",
                  scale = 4}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":asphalt",
    {
        description = "Asphalt",
        tiles = {{name = mod_name.."_asphalt.png",
                  align_style = "world",
                  scale = 8}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":bricks_gray",
    {
        description = "Gray Bricks",
        tiles = {{name = mod_name.."_bricks_gray.png",
                  align_style = "world",
                  scale = 4}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":bricks_red",
    {
        description = "Red Bricks",
        tiles = {{name = mod_name.."_bricks_red.png",
                  align_style = "world",
                  scale = 2}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",

    }
)

local roughcast_list = {
    {name = "red", desc = "Red Roughcast"},
    {name = "yellow", desc = "Yellow Roughcast"},
    {name = "yellow_light", desc = "Light Yellow Roughcast"},
    {name = "green", desc = "Green Roughcast"},
    {name = "white", desc = "White Roughcast"},
    {name = "blue", desc = "White Roughcast"},
}

for _, roughcast in pairs(roughcast_list) do
    minetest.register_node(
        mod_name..":roughcast_"..roughcast.name,
        {
            description = roughcast.name,
            tiles = {{name = mod_name.."_roughcast_"..roughcast.name..".png",
                      align_style = "world",
                      scale = 4}},
            groups = {snappy = 3, stone = 1},
            paramtype = "light",
        }
    )
end

minetest.register_node(
    mod_name..":pavement",
    {
        description = "Pavement",
        tiles = {{name = mod_name.."_pavement.png",
                  align_style = "world",
                  scale = 5}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

minetest.register_node(
    mod_name..":grass",
    {
        description = "Grass",
        tiles = {{name = mod_name.."_grass.png",
                  align_style = "world",
                  scale = 8}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
    }
)

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
