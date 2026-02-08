--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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

--[[
    ** Perfect City Mapgen Module **
    This is the initialization file for the pcity_mapgen module.
    It sets up the mapgen environment, registers biomes, and loads
    the main mapgen script.
--]]

-- This mod name and path
local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

-- Create global table for mapgen
pcity_mapgen = {}

-- Cirno's Perfect Math Library
local CPML_mod_path = core.get_modpath("pcity_cpml")

-- Register node aliases to replace default mapgen nodes with city nodes
-- This ensures the mapgen uses our custom nodes instead of default stone/water
core.register_alias("mapgen_stone", "pcity_nodes:asphalt")
core.register_alias("mapgen_water_source", "pcity_nodes:pavement")
core.register_alias("mapgen_river_water_source", "pcity_nodes:pavement")

-- Configure mapgen flags for city generation
-- nocaves: no cave generation (cities don't have natural caves)
-- nodungeons: no dungeon generation
-- light: calculate lighting (important for city atmosphere)
-- decorations: allow decorations
-- biomes: use biome system
core.set_mapgen_setting("mg_flags", "nocaves, nodungeons, light, decorations, biomes", true)

-- Optionally enable hills for varied terrain
if core.settings:get("pcity_enable_hills") == "true" then
    core.set_mapgen_setting("mgflat_spflags", "nolakes, hills, nocaverns", true)
end

-- Load biome definitions
dofile(mod_path.."/biomes.lua")

-- Load test suite
dofile(mod_path.."/tests/init.lua")

-- Register math library and main mapgen script
core.register_mapgen_script(CPML_mod_path.."/init.lua")
core.register_mapgen_script(mod_path.."/mapgen.lua")
