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

local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath("pcity_mapgen")
local pcmg = pcity_mapgen

pcmg.metastore = {}
local metastore = pcmg.metastore
metastore.__index = metastore

--[[
    ** Metastore **
    Metastore is a class of objects that allow storing meta data for
    objects without modifying them directly. Metastore keeps a private
    table for each object added to it and allows setting/getting
    values by key.  Metastore uses tables with weak keys so when the
    object is destroyed, store contents get garbage collected.
--]]

local private = setmetatable({}, {__mode = "k"})
local private_const = setmetatable({}, {__mode = "k"})

function metastore:__newindex(key, value)
    -- forbid setting new keys for this class
    minetest.log("error", "Metastore: Don't set values directly, use 'metastore:set', etc. instead.")
end

function metastore.new()
    local m = setmetatable({}, metastore)
    private[m] = setmetatable({}, {__mode = "k"})
    private_const[m] = setmetatable({}, {__mode = "k"})
    return m
end

function metastore.check(m)
    return getmetatable(m) == metastore
end

function metastore:init_store(object)
    if type(object) ~= "table" then
        error("Metastore: Trying to initialize storage, but 'object': "..
              dump(object).." is not a table.")
    end
    local store = private[self]
    local store_const = private_const[self]
    if not store[object] then
        store[object] = {}
    end
    if not store_const[object] then
        store_const[object] = {}
    end
end

function metastore:set(object, key, value)
    self:init_store(object)
    local store = private[self]
    local store_const = private_const[self]
    store[object][key] = value
end

function metastore:constant(object, key, value)
    self:init_store(object)
    local store = private_const[self]
    local store_const = private_const[self]
    store[object][key] = nil
    store_const[object][key] = value
end

function metastore:get(object, key)
    self:init_store(object)
    local store = private[self]
    local store_const = private_const[self]
    return store_const[object][key] or store[object][key]
end
