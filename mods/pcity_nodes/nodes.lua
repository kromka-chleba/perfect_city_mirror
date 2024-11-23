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

function pcn.get_hard_sound(table)
  table = type(table) == "table" and table or {}
  if not table.footstep then
    table.footstep = {name = "pcity_nodes_hard_footstep", pitch = 0.7, gain = 0.8}
  end
  return table
end
