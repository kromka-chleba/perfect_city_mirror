--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    SPDX-License-Identifier: AGPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

--[[
    Shared utility functions for path/point checks (extracted from
    point.lua and path.lua).
--]]

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local pcmg = pcity_mapgen

pcmg.point_checks = pcmg.point_checks or {}
local checks = pcmg.point_checks

-- Validates arguments passed to 'point.new'.
function checks.check_point_new_arguments(pos)
    if not vector.check(pos) then
        error("Path: pos '"..shallow_dump(pos).."' is not a vector.")
    end
end

-- Checks if 'p' is a point, otherwise throws an error.
-- This resolves the point checker at call time to avoid circular loads.
function checks.check_point(p)
    if not (pcmg and pcmg.point and pcmg.point.check and pcmg.point.check(p)) then
        error("Path: p '"..shallow_dump(p).."' is not a point.")
    end
end

-- Check if points belong to the same path. 'points' is an array/table.
-- Resolves point.same_path at call time.
function checks.check_same_path(points)
    if not (pcmg and pcmg.point and pcmg.point.same_path) then
        error("Path: internal error - point.same_path not available.")
    end
    if not pcmg.point.same_path(unpack(points)) then
        error("Path: Cannot link points that belong to different paths.")
    end
end

-- Checks if arguments passed to 'path:insert_between' are valid.
function checks.check_insert_between_arguments(self, p_prev, p_next, p)
    checks.check_point(p)
    checks.check_point(p_prev)
    checks.check_point(p_next)
    checks.check_same_path({self.start, p_prev, p_next, self.finish})
    -- Verify that p_prev and p_next are actually adjacent
    if p_prev.next ~= p_next then
        error("Path: p_prev and p_next are not adjacent points.")
    end
end

-- Checks if arguments passed to 'path:remove', 'path:remove_before'
-- and 'path:remove_after' are valid. Only intermediate points can be
-- removed (not start or finish).
function checks.check_remove_arguments(self, p)
    if not self.points[p] then
        error("Path: p '"..shallow_dump(p).."' does not belong to the path.")
    end
    if p == self.start or p == self.finish then
        error("Path: cannot remove start or finish point.")
    end
    if not self:has_intermediate() then
        error("Path: there are no intermediate points to remove.")
    end
end

-- Checks if arguments passed to 'path:remove_at' are valid.
function checks.check_remove_at_arguments(self, nr)
    if type(nr) ~= "number" then
        error("Path: nr '"..shallow_dump(nr).."' is not a number.")
    end
    local p = self:get_point(nr)
    if not p then
        error("Path: no intermediate point at nr '"..shallow_dump(nr).."'.")
    end
end

-- Checks if arguments passed to 'path:split_at' are valid.
function checks.check_split_at_arguments(self, p)
    -- use check_same_path to validate
    checks.check_same_path({self.start, p, self.finish})
    -- check if 'p' is an intermediate point
    if p == self.start or p == self.finish then
        error("Path: cannot split path at start or finish point.")
    end
    if not self:has_intermediate() then
        error("Path: cannot split path with no intermediate points.")
    end
end

return checks
