--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    SPDX-License-Identifier: AGPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

local materials_by_id = {
    [1] = {id = 1, name = "blank", priority = 0},
    [2] = {id = 2, name = "road_asphalt", priority = 3},
    [3] = {id = 3, name = "road_pavement", priority = 2},
    [4] = {id = 4, name = "road_margin", priority = 1},
    [5] = {id = 5, name = "road_center", priority = 4},

    -- Meta
    [1000] = {id = 1000, name = "road_midpoint", priority = 1000},
    [1001] = {id = 1001, name = "road_origin", priority = 1001},
}

local materials_by_name = {}

for id, material in pairs(materials_by_id) do
    materials_by_name[material.name] = id
end

return materials_by_id, materials_by_name
