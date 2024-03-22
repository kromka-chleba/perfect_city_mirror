--[[
    This is a part of "Perfect City".
    Copyright (C) 2023, 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
---------------------------------------------------

-- General texture operations

local function tx_name(name)
    return mod_name.."_"..name..".png"
end

local function overlay(textures, new_textures)
    if type(new_textures) == "string" then
        for side, texture in pairs(textures) do
            textures[side] = texture.."^"..new_textures
        end
    elseif type(new_textures) == "table" then
        for side, new_texture in pairs(new_textures) do
            textures[side] = textures[side].."^"..new_textures[side]
        end
    end
end

local function overlay_horizontal(textures, new_texture)
    local horizontal = {
        front = new_texture,
        back = new_texture,
        left = new_texture,
        right = new_texture,
    }
    overlay(textures, horizontal)
end

local function textuers_to_mt_format(textures)
    local new_textures = {}
    new_textures[1] = textures.up
    new_textures[2] = textures.down
    new_textures[3] = textures.front
    new_textures[4] = textures.back
    new_textures[5] = textures.left
    new_textures[6] = textures.right
    return new_textures
end

-- Perfect City specific textures and functions

local base_gray_tx = tx_name("base")
local base_black_tx = tx_name("base_black")
local base_blue_tx = tx_name("base_blue")
local down_tx = tx_name("down")
local noise_tx = tx_name("noise")
local horizon_tx = tx_name("horizon")
local city_tx = tx_name("city")
local chimneys_tx = tx_name("chimneys_left")
local cranes = {
    front = tx_name("cranes_front"),
    back = tx_name("cranes_back"),
    left = tx_name("cranes_left"),
    right = tx_name("cranes_right"),
}
local power_lines_tx = tx_name("power_lines")
local silos_tx = tx_name("silos")
local smog_tx = tx_name("smog")

local function sky_base_textures(base_tx)
    local textures = {
        up = base_tx,
        down = down_tx,
        front = base_tx,
        back = base_tx,
        left = base_tx,
        right = base_tx,
    }
    return textures
end

local function overlay_horizon(textures)
    overlay_horizontal(textures, horizon_tx)
end

local function overlay_city(textures)
    overlay_horizontal(textures, city_tx)
end

local function overlay_cranes(textures)
    overlay(textures, cranes)
end

local function overlay_power_lines(textures)
    overlay(textures, {left = power_lines_tx})
end

local function overlay_silos(textures)
    overlay(textures, {front = silos_tx})
end

local function overlay_chimneys(textures)
    overlay(textures, {left = chimneys_tx})
end

local function overlay_smog(textures)
    overlay_horizontal(textures, smog_tx)
end

local function overlay_noise(textures)
    overlay(textures, noise_tx)
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
    local raw_textures = sky_base_textures(base_gray_tx)
    overlay_horizon(raw_textures)
    overlay_chimneys(raw_textures)
    overlay_power_lines(raw_textures)
    overlay_silos(raw_textures)
    overlay_monster(raw_textures)
    overlay_city(raw_textures)
    overlay_cranes(raw_textures)
    overlay_noise(raw_textures)
    overlay_smog(raw_textures)
    return textuers_to_mt_format(raw_textures)
end

---------------------------------------------------
-- In this section sky operations happen
---------------------------------------------------

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
