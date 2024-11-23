--[[
    This is a part of "Perfect City".
    Copyright (C) 2023 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    Copyright (C) 2024 TubberPupper (TPH)

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

local pcn = pcity_nodes

minetest.register_node(
    mod_name..":asphalt",
    {
        description = "Asphalt",
        tiles = {{name = mod_name.."_asphalt.png",
                  align_style = "world",
                  scale = 8}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":pavement",
    {
        description = "Pavement",
        tiles = {{name = mod_name.."_pavement.png",
                  align_style = "world",
                  scale = 5}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_middle",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb.obj",
        description = "Curb",
        tiles = {{name = mod_name.."_curb_middle.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, -0.25},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, -0.25},
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_gap",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb.obj",
        description = "Curb gap",
        tiles = {{name = mod_name.."_curb_middle.png^"..
                      mod_name.."_curb_gap.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, -0.25},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, -0.25},
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_corner",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_corner.obj",
        description = "Curb",
        tiles = {{name = mod_name.."_curb_middle.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, -0.3, -0.25},
                {0.25, -0.5, -0.5, 0.5, -0.3, 0.5},
            },
        },
        collision_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, -0.3, 0.0},
                {-0.5, -0.5, 0.0, 0.0, -0.3, 0.5},
            },
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_small",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_small.obj",
        description = "Curb Small",
        tiles = {{name = mod_name.."_curb_middle.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, -0.25, -0.3, -0.25},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, -0.25, -0.3, -0.25},
            --fixed = {-0.5, -0.5, -0.5, 0.0, -0.3, 0.0},
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_road",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_road.obj",
        description = "Road Curb",
        tiles = {{name = mod_name.."_curb_road.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, 0},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, 0},
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_road_corner",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_road_corner.obj",
        description = "Road Curb Corner",
        tiles = {{name = mod_name.."_curb_road_slab.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, -0.3, 0.0},
                {-0.5, -0.5, 0.0, 0.0, -0.3, 0.5},
            },
        },
        collision_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, -0.3, 0.0},
                {-0.5, -0.5, 0.0, 0.0, -0.3, 0.5},
            },
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_road_small",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_road_small.obj",
        description = "Road Curb Small",
        tiles = {{name = mod_name.."_curb_road.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.0, -0.3, 0.0},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.0, -0.3, 0.0},
        },
        sounds = pcn.get_hard_sound()
    }
)

minetest.register_node(
    mod_name..":curb_road_slab",
    {
        drawtype = "mesh",
        mesh = mod_name.."_curb_road_slab.obj",
        description = "Road Curb Slab",
        tiles = {{name = mod_name.."_curb_road_slab.png"}},
        groups = {cracky = 3, stone = 1},
        paramtype = "light",
        paramtype2 = "4dir",
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
        },
        sounds = pcn.get_hard_sound()
    }
)
