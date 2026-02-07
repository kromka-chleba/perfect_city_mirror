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

local mod_name = core.get_current_modname()

local pcc = pcity_common
local itemstore_api = itemstore_api

-- Shelf 1

local shelf_1_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1.obj",
    description = "Shelf 1",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.5,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.5,
             0.5, 0.5, 0.5},
            -- shelf left
            {-0.5, -0.5, -0.5,
             -0.4, 0.5, 0.5},
            -- shelf right
            {0.4, -0.5, -0.5,
             0.5, 0.5, 0.5},
        }
    },
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_left_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_left.obj",
    description = "Shelf 1 Left",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.5,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.5,
             0.5, 0.5, 0.5},
            -- shelf left
            {-0.5, -0.5, -0.5,
             -0.4, 0.5, 0.5},
        }
    },
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_middle_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_middle.obj",
    description = "Shelf 1 Middle",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.5,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.5,
             0.5, 0.5, 0.5},
        }
    },
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_right_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_right.obj",
    description = "Shelf 1 Right",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.5,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.5,
             0.5, 0.5, 0.5},
            -- shelf left
            {0.4, -0.5, -0.5,
             0.5, 0.5, 0.5},
        }
    },
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

-- Shelf 1 double shallow

local shallow_collision_box = {
    type = "fixed",
    fixed = {
        {-0.5, -0.5, -0.1,
         0.5, 0.5, 0.5},
    }
}

local shelf_1_double_shallow_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_double_shallow.obj",
    description = "Shelf 1 Double Shallow",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.1,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.1,
             0.5, 0.5, 0.5},
            -- shelf left
            {-0.5, -0.5, -0.1,
             -0.4, 0.5, 0.5},
            -- shelf right
            {0.4, -0.5, -0.1,
             0.5, 0.5, 0.5},
        }
    },
    collision_box = shallow_collision_box,
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_double_shallow_left_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_double_shallow_left.obj",
    description = "Shelf 1 Double Shallow Left",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.1,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.1,
             0.5, 0.5, 0.5},
            -- shelf left
            {-0.5, -0.5, -0.1,
             -0.4, 0.5, 0.5},
        }
    },
    collision_box = shallow_collision_box,
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_double_shallow_middle_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_double_shallow_middle.obj",
    description = "Shelf 1 Double Shallow Middle",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.1,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.1,
             0.5, 0.5, 0.5},
        }
    },
    collision_box = shallow_collision_box,
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

local shelf_1_double_shallow_right_nodedef = {
    drawtype = "mesh",
    mesh = mod_name.."_shelf_1_double_shallow_right.obj",
    description = "Shelf 1 Double Shallow Right",
    tiles = {
        {name = pcc.color_palette},
    },
    selection_box = {
        type = "fixed",
        fixed = {
            -- shelf bottom
            {-0.5, -0.5, -0.1,
             0.5, -0.4, 0.5},
            -- shelf back
            {-0.5, -0.5, 0.4,
             0.5, 0.5, 0.5},
            -- shelf top
            {-0.5, 0.4, -0.1,
             0.5, 0.5, 0.5},
            -- shelf left
            {0.4, -0.5, -0.1,
             0.5, 0.5, 0.5},
        }
    },
    collision_box = shallow_collision_box,
    groups = {cracky = 3, stone = 1},
    paramtype = "light",
    paramtype2 = "4dir",
}

-- Shelf 1

itemstore_api.register_itemstore(
    mod_name..":shelf_1", shelf_1_nodedef, "basic_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_left", shelf_1_left_nodedef, "basic_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_middle", shelf_1_middle_nodedef, "basic_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_right", shelf_1_right_nodedef, "basic_shelf")

-- Shelf 1 double shallow

itemstore_api.register_itemstore(
    mod_name..":shelf_1_double_shallow", shelf_1_double_shallow_nodedef, "shallow_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_double_shallow_left", shelf_1_double_shallow_left_nodedef, "shallow_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_double_shallow_middle", shelf_1_double_shallow_middle_nodedef, "shallow_shelf")

itemstore_api.register_itemstore(
    mod_name..":shelf_1_double_shallow_right", shelf_1_double_shallow_right_nodedef, "shallow_shelf")
