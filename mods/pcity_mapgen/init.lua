pcity_mapgen = {}

-- Load files
local path = minetest.get_modpath("pcity_mapgen")

-- These are necessary so the mapgen works at all lol
minetest.register_alias("mapgen_stone", "pcity_nodes:asphalt")
minetest.register_alias("mapgen_water_source", "pcity_nodes:pavement")
minetest.register_alias("mapgen_river_water_source", "pcity_nodes:pavement")

minetest.set_mapgen_setting("mg_flags", "nocaves, nodungeons, light, decorations, biomes", true)

if minetest.settings:get("pcity_enable_hills") == "true" then
    minetest.set_mapgen_setting("mgflat_spflags", "nolakes, hills, nocaverns", true)
end

dofile(path.."/mapgen.lua")
