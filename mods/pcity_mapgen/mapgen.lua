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

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
pcity_mapgen = {}
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

dofile(mod_path.."/metastore.lua")
dofile(mod_path.."/utils.lua")
dofile(mod_path.."/point.lua")
dofile(mod_path.."/path_utils.lua")
dofile(mod_path.."/path.lua")
dofile(mod_path.."/pathpaver.lua")
dofile(mod_path.."/megapathpaver.lua")
dofile(mod_path.."/canvas_brushes.lua")
dofile(mod_path.."/canvas.lua")
dofile(mod_path.."/megacanvas.lua")
dofile(mod_path.."/roads_layout.lua")
-- TODO: roads_mapgen.lua file is missing - needs to be created with write_roads function
-- dofile(mod_path.."/roads_mapgen.lua")
dofile(mod_path.."/debug_helpers.lua")

-- Temporary stub for missing write_roads function
function pcmg.write_roads(mapgen_args, canvas)
    -- TODO: Implement road writing to mapgen
    -- This function should take the canvas and write it to the VoxelManip
    core.log("warning", "pcmg.write_roads is not implemented yet - roads will not be generated")
end

--[[
    ** Mapgen **
    The map is divided into regions called citychunks. Each citychunk
    is a square with a side of (by default) 10 mapchunks - 800 nodes,
    this value can be however changed with the "pcity_citychunk_size"
    setting (see sizes.lua for details). The citychunk is a basic unit
    of map generation, which means everything from roads, through
    streets to buildings is planned on this level which allows
    localizing mapgen to relatively small pieces of map.
    The citychunk grid is aligned with the mapchunk grid and starts at
    xyz: -32.
--]]

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

local mapgen_seed = core.get_mapgen_setting("seed")

core.log("error", mapgen_seed)

-- Cache for canvas and paths
local road_canvas_cache = pcmg.megacanvas.cache.new()
local pathpaver_cache = pcmg.megapathpaver.cache.new()

local function mapgen(vm, pos_min, pos_max, blockseed)
    local t1 = core.get_us_time()
    local mapgen_args = {vm, pos_min, pos_max, blockseed}
    if pos_max.y >= sizes.ground_level and sizes.ground_level >= pos_min.y then
        pcmg.debug.helper_grid(mapgen_args)
        local citychunk_origin = pcmg.citychunk_origin(pos_min)
        local hash = pcmg.citychunk_hash(pos_min)
        if not road_canvas_cache.complete[hash] then
            local megacanv = pcmg.megacanvas.new(citychunk_origin, road_canvas_cache)
            pcmg.generate_roads(megacanv, pathpaver_cache)
        end
        local canvas = road_canvas_cache.citychunks[hash]
        pcmg.write_roads(mapgen_args, canvas)
        --core.log("error", string.format("elapsed time: %g ms", (core.get_us_time() - t1) / 1000))
    end
end

core.register_on_generated(mapgen)
