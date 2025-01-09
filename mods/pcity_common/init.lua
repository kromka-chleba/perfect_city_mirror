--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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

-- This mod name and path
local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath(mod_name)

pcity_common = {}
local pcity_common = pcity_common

pcity_common.color_palette = "pcity_common_palette.png"

function pcity_common.node_name(name, mod_name)
    return mod_name..":"..name
end

function pcity_common.texture_name(name, mod_name)
    return mod_name.."_"..name..".png"
end

function pcity_common.get_nodedef(pos)
    local node = core.get_node(pos)
    return core.registered_nodes[node.name]
end

function pcity_common.node_dir(pos)
    local node = core.get_node(pos)
    local param2 = node.param2
    local paramtype2 = pcity_common.get_nodedef(pos).paramtype2
    if paramtype2 == "4dir" then
        return core.fourdir_to_dir(param2)
    elseif paramtype2 == "facedir" then
        return core.facedir_to_dir(param2)
    elseif paramtype2 == "wallmounted" then
        return core.wallmounted_to_dir(param2)
    end
end

function pcity_common.node_rotation(pos)
    local dir = pcity_common.node_dir(pos)
    return vector.dir_to_rotation(dir)
end
