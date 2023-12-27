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

---------------------------------------------------
-- In this section only texture operations happen

local function tx_name(name)
    return mod_name.."_"..name..".png"
end

local down_tx = tx_name("down")
local noise_tx = tx_name("noise")
local city_tx = tx_name("city")
local chimneys_tx = tx_name("chimneys_left")
local cranes_front_tx = tx_name("cranes_front")
local cranes_back_tx = tx_name("cranes_back")
local cranes_left_tx = tx_name("cranes_left")
local cranes_right_tx = tx_name("cranes_right")
local smog_tx = tx_name("smog")

local function sky_noise_textures()
    local textures = {
        up = noise_tx,
        down = down_tx,
        front = noise_tx,
        back = noise_tx,
        left = noise_tx,
        right = noise_tx,
    }
    return textures
end

local function overlay_city(textures)
    textures.front = textures.front.."^"..city_tx
    textures.back = textures.back.."^"..city_tx
    textures.left = textures.left.."^"..city_tx
    textures.right = textures.right.."^"..city_tx
end

local function overlay_cranes(textures)
    textures.front = textures.front.."^"..cranes_front_tx
    textures.back = textures.back.."^"..cranes_back_tx
    textures.left = textures.left.."^"..cranes_left_tx
    textures.right = textures.right.."^"..cranes_right_tx
end

local function overlay_chimneys(textures)
    textures.left = textures.left.."^"..chimneys_tx
end

local function overlay_smog(textures)
    textures.front = textures.front.."^"..smog_tx
    textures.back = textures.back.."^"..smog_tx
    textures.left = textures.left.."^"..smog_tx
    textures.right = textures.right.."^"..smog_tx
end

local monster_texture = tx_name("crane_monster")
local monster_dimensions = "26x69"
local monster_coords = {
    "10,468",
    "68,468",
    "303,468",
    "360,468",
    "480,468",
    "969,468",
}

local function overlay_monster(textures)
    local random_monster = monster_coords[math.random(1, #monster_coords)]
    local monster = "^[combine:"..monster_dimensions..":"..random_monster.."="..monster_texture
    textures.back = textures.back..monster
end

-- Ready to use sky textures translated into the minetest format
local function default_textures()
    local raw_textures = sky_noise_textures()
    overlay_city(raw_textures)
    overlay_chimneys(raw_textures)
    overlay_cranes(raw_textures)
    overlay_monster(raw_textures)
    overlay_smog(raw_textures)
    local textures = {}
    textures[1] = raw_textures.up
    textures[2] = raw_textures.down
    textures[3] = raw_textures.front
    textures[4] = raw_textures.back
    textures[5] = raw_textures.left
    textures[6] = raw_textures.right

    return textures
end

---------------------------------------------------
-- In this section sky operations happen

local clouds = {
    density = 0.4,
    color = "#747c7f",
    ambient = "#372f25",
    --height = 120,
    --thickness = 16,
    --speed = {x=0, z=-2},
}

local function get_default_sky()
    local default_sky = {
        type = "skybox",
        clouds = true,
        body_orbit_tilt = -30,
        base_color = "#3e423f",
        textures = default_textures(),
        fog = {
            fog_distance = 200,
        },
    }
    return default_sky
end

local current_sky = get_default_sky()
local refresh_interval = 100

-- This refreshes stuff on the sky
-- for now it moves the monster around
local function refresh_sky()
    current_sky = get_default_sky()
    local players = minetest.get_connected_players()
    for _, player in pairs(players) do
        player:set_sky(current_sky)
        player:set_clouds(clouds)
    end
    minetest.after(refresh_interval, refresh_sky)
    return
end

minetest.after(refresh_interval, refresh_sky)

-- Loads current sky for players who just connected
minetest.register_on_joinplayer(
    function(player, last_login)
        player:set_sky(current_sky)
        player:set_clouds(clouds)
end)
