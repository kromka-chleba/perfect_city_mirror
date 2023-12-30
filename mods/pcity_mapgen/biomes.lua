--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
local pc_sizes = dofile(mod_path.."/sizes.lua")

minetest.register_biome({
        name = "city",
        node_top = "pcity_nodes:grass",
        depth_top = 1,
        node_filler = "pcity_nodes:concrete",
        depth_filler = 3,
        node_stone = "pcity_nodes:asphalt",
        vertical_blend = 0,
        y_max = pc_sizes.city_max,
        y_min = pc_sizes.ground_level - 5,
        heat_point = 50,
        humidity_point = 50,
})
