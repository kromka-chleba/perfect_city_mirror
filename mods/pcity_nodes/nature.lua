--[[
    This is a part of "Perfect City".
    Copyright (C) 2023 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    Copyright (C) 2024 TubberPupper (TPH)

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

local pcn = pcity_nodes

minetest.register_node(
    mod_name..":grass",
    {
        description = "Grass",
        tiles = {{name = mod_name.."_grass.png",
                  align_style = "world",
                  scale = 8}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        sounds = {
          footstep = {name = "pcity_nodes_grass_footstep", gain = 2, pitch = 0.8}
        }
    }
)
