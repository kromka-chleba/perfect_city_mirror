-- Mapchunk Shepherd
-- License: GNU GPLv3
-- Copyright © Jan Wielkiewicz 2023

local mod_storage = minetest.get_mod_storage()

-- By default chunksize is 5
local blocks_per_chunk = tonumber(minetest.get_mapgen_setting("chunksize"))
local chunk_side = blocks_per_chunk * 16
-- this logic comes from Minetest source code, see src/mapgen/mapgen.cpp
local mapchunk_offset = -16 * math.floor(blocks_per_chunk / 2)
local old_chunksize = mod_storage:get_int("chunksize")

return {
    blocks_per_chunk = blocks_per_chunk,
    chunk_side = chunk_side,
    mapchunk_offset = mapchunk_offset,
    old_chunksize = old_chunksize
}
