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
        sounds = pcn.get_hard_sound()
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
        sounds = pcn.get_hard_sound()
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
        sounds = pcn.get_hard_sound()

    }
)

local roughcast_list = {
    {name = "red", desc = "Red Roughcast",hsl={h=6,s=38,l=-45}},
    {name = "yellow", desc = "Yellow Roughcast",hsl={h=38,s=60,l=-30}},
    {name = "yellow_light", desc = "Light Yellow Roughcast",hsl={h=42,l=-22}},
    {name = "green", desc = "Green Roughcast",hsl={h=115,l=-26}},
    {name = "white", desc = "White Roughcast",hsl={h=-178,s=0,l=25}},
    {name = "blue", desc = "Blue Roughcast", hsl={h=-172,l=-5}},
}

for _, roughcast in pairs(roughcast_list) do
    local hsl = roughcast.hsl or {}
    hsl.h = hsl.h or 0
    hsl.s = hsl.s or 24 -- this number used by blue, green, light yellow
    local color = table.concat({hsl.h, hsl.s, hsl.l},":")
    minetest.register_node(
        mod_name..":roughcast_"..roughcast.name,
        {
            description = roughcast.desc or roughcast.name,
            -- modify the hue saturation lightness of base texture
            tiles = {{name = mod_name.."_roughcast.png^[colorizehsl:"..color,
                      align_style = "world",
                      scale = 4}},
            groups = {snappy = 3, stone = 1},
            paramtype = "light",
        }
    )
end
