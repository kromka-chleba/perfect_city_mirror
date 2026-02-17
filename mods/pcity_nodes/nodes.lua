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

local mod_name = core.get_current_modname()

local pcn = pcity_nodes

--- Gets hard sound table for nodes.
-- Returns a table with footstep sound configuration. If the input table
-- doesn't have a footstep sound, adds a default hard footstep sound.
-- @param table table Optional sound configuration table
-- @return table Sound configuration with footstep sound
function pcn.get_hard_sound(table)
  table = type(table) == "table" and table or {}
  if not table.footstep then
    table.footstep = {name = "pcity_nodes_hard_footstep", pitch = 0.7, gain = 0.8}
  end
  return table
end
