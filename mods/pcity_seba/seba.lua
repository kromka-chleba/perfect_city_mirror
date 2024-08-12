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

-- The hand
minetest.register_item(
    ":",
    {
        type = "none",
        wield_image = "wieldhand.png",
        wield_scale = {x = 1, y = 1, z = 2.5},
        liquids_pointable = true,
        tool_capabilities = {
            full_punch_interval = 1,
            groupcaps = {
                choppy = {times={[3] = 1}, uses = 0},
                crumbly = {times={[3] = 1}, uses = 0},
                snappy = {times={[3] = 1}, uses = 0},
                cracky = {times={[3] = 1}, uses = 0},
                oddly_breakable_by_hand = {
                    times={
                        [1] = 1,
                        [2] = 1,
                        [3] = 1}, uses=0
                },
            },
            damage_groups = {fleshy = 1},
        },
})
