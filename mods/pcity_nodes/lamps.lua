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

local mod_name = core.get_current_modname()

local pcc = pcity_common

core.register_node(
    mod_name..":ceiling_lamp_1",
    {
        drawtype = "mesh",
        mesh = mod_name.."_ceiling_lamp_1.obj",
        description = "Ceiling Lamp 1",
        tiles = {
            {name = pcc.color_palette},
        },
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        light_source = 14,
    }
)
