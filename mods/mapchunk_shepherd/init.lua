---------------------------------------------
---- Mapchunk shepherd
---------------------------------------------

-- Globals
mapchunk_shepherd = {}

local modpath = minetest.get_modpath('mapchunk_shepherd')
local S = minetest.get_translator("mapchunk_shepherd")

mapchunk_shepherd.S = S

dofile(modpath.."/labels.lua")
dofile(modpath.."/chunk_utils.lua")
dofile(modpath.."/dogs.lua")
dofile(modpath.."/shepherd.lua")
