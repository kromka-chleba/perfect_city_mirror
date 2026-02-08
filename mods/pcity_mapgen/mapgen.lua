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
dofile(mod_path.."/roads_mapgen.lua")
dofile(mod_path.."/debug_helpers.lua")

--[[
    ** Mapgen Script **
    This is the main mapgen script that runs when chunks are generated.
    
    The map is divided into regions called citychunks. Each citychunk
    is a square with a side of (by default) 10 mapchunks - 800 nodes.
    This value can be changed with the "pcity_citychunk_size" setting
    (see sizes.lua for details).
    
    The citychunk is the basic unit of map generation, which means
    everything from roads through streets to buildings is planned at
    this level. This allows localizing mapgen to relatively small
    pieces of map for better performance and organization.
    
    The citychunk grid is aligned with the mapchunk grid and starts
    at xyz: -32 (the default mapgen offset).
--]]

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-- Get mapgen seed for deterministic generation
local mapgen_seed = core.get_mapgen_setting("seed")

-- Log seed for debugging (TODO: remove or make conditional)
core.log("error", mapgen_seed)

-- Cache for canvas and pathpaver objects to improve performance
-- These caches prevent regenerating the same citychunks
local road_canvas_cache = pcmg.megacanvas.cache.new()
local pathpaver_cache = pcmg.megapathpaver.cache.new()

-- Main mapgen function called by Minetest for each generated mapchunk
-- vm: VoxelManip object for reading/writing nodes
-- pos_min, pos_max: Bounds of the mapchunk being generated
-- blockseed: Seed for this specific block (not currently used)
local function mapgen(vm, pos_min, pos_max, blockseed)
    -- Track generation time for performance monitoring
    local t1 = core.get_us_time()
    local mapgen_args = {vm, pos_min, pos_max, blockseed}
    
    -- Only generate at ground level (roads are horizontal)
    if pos_max.y >= sizes.ground_level and sizes.ground_level >= pos_min.y then
        -- Draw debug grid to visualize chunk boundaries
        pcmg.debug.helper_grid(mapgen_args)
        
        -- Get citychunk coordinates for this mapchunk
        local citychunk_origin = pcmg.citychunk_origin(pos_min)
        local hash = pcmg.citychunk_hash(pos_min)
        
        -- Generate roads if not already cached
        if not road_canvas_cache.complete[hash] then
            local megacanv = pcmg.megacanvas.new(citychunk_origin, road_canvas_cache)
            pcmg.generate_roads(megacanv, pathpaver_cache)
        end
        
        -- Write roads to the voxel manipulator
        local canvas = road_canvas_cache.citychunks[hash]
        pcmg.write_roads(mapgen_args, canvas)
        
        -- Log generation time (commented out for production)
        --core.log("error", string.format("elapsed time: %g ms", (core.get_us_time() - t1) / 1000))
    end
end

-- Register the mapgen function to be called by Minetest
core.register_on_generated(mapgen)
