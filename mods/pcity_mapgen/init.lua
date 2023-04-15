pcity_mapgen = {}

-- Load files
local path = minetest.get_modpath("pcity_mapgen")

dofile(path.."/mapgen.lua")

minetest.register_alias("mapgen_stone", "pcity_nodes:asphalt")
minetest.register_alias("mapgen_water_source", "pcity_nodes:asphalt")
