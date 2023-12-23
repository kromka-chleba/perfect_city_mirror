--[[
    This is a part of "Perfect City".
    Copyright (C) 2023 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
local math = math

local monster_texture = mod_name.."_crane_monster.png"
local monster_dimensions = "26x69"
local monster_coords = {
    "10,468",
    "68,468",
    "303,468",
    "360,468",
    "480,468",
    "969,468",
}

local function get_default_sky_textures()
    local textures = {
        up = mod_name.."_up.png",
        down = mod_name.."_down.png",
        front = mod_name.."_front.png",
        back = mod_name.."_back.png",
        left = mod_name.."_left.png",
        right = mod_name.."_right.png",
    }
    return textures
end

local function prepare_sky_textures(sky_textures)
    local textures = {}
    textures[1] = sky_textures.up
    textures[2] = sky_textures.down
    textures[3] = sky_textures.front
    textures[4] = sky_textures.back
    textures[5] = sky_textures.left
    textures[6] = sky_textures.right
    return textures
end

local function get_default_sky()
    local raw_textures =  get_default_sky_textures()
    local textures = prepare_sky_textures(raw_textures)
    local default_sky = {
        type = "skybox",
        clouds = true,
        body_orbit_tilt = -30,
        base_color = "#3e423f",
        textures = textures,
        fog = {
            fog_distance = 150,
        },
    }
    return default_sky
end

local function randomize_monster()
    local random_monster = monster_coords[math.random(1, #monster_coords)]
    local monster = "^[combine:"..monster_dimensions..":"..random_monster.."="..monster_texture
    return monster
end

local current_sky = get_default_sky()
local refresh_interval = 100

-- This refreshes stuff on the sky
-- for now it moves the monster around
local function refresh_sky()
    local new_sky = get_default_sky()
    local raw_textures = get_default_sky_textures()
    raw_textures.back = raw_textures.back..randomize_monster()
    new_sky.textures = prepare_sky_textures(raw_textures)
    current_sky = new_sky
    local players = minetest.get_connected_players()
    for _, player in pairs(players) do
        player:set_sky(new_sky)
    end
    minetest.after(refresh_interval, refresh_sky)
    return
end

minetest.after(refresh_interval, refresh_sky)

-- Loads current sky for players who just connected
minetest.register_on_joinplayer(
    function(player, last_login)
        player:set_sky(current_sky)
end)
