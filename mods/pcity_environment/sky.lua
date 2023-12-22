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

local random_monster = monster_coords[math.random(1, #monster_coords)]

local current_sky = {
    type = "skybox",
    clouds = true,
    body_orbit_tilt = -60,
    base_color = "#3e423f",
    textures = {
        mod_name.."_up.png",
        mod_name.."_down.png",
        mod_name.."_front.png",
        mod_name.."_back.png".."^[combine:"..monster_dimensions..":"..random_monster.."="..monster_texture,
        mod_name.."_left.png",
        mod_name.."_right.png",
    },
    fog = {
        fog_distance = 150,
    },
}

minetest.register_on_joinplayer(
    function(player, last_login)
        player:set_sky(current_sky)
end)
