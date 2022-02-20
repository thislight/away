-- Copyright (C) 2021 thisLight
-- 
-- This file is part of away.
-- 
-- away is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- away is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with away.  If not, see <http://www.gnu.org/licenses/>.
local a = require "away"

local series_methods = {}

local function create()
    return setmetatable({nil, }, { __index = series_methods })
end

local broadcast_methods = {}

local function create_broadcast()
    return setmetatable({{}}, { __index = broadcast_methods })
end

local function create_pair()
    return create(), create()
end

function series_methods:put(val)
    a.schedule_task(function()
        self[1](val)
    end)
end

function broadcast_methods:put(val)
    a.schedule_task(function()
        for i, v in ipairs(self[1]) do
            v(val)
        end
    end)
end

function series_methods:has_value()
    return #self > 1
end

function series_methods:listen(callback)
    assert(self[1] == nil, "non broadcast series should only listen once")
    self[1] = callback
    return callback
end

function series_methods:dismiss(callback)
    self[1] = nil
end

function broadcast_methods:listen(callback)
    self[1][#self[1]+1] = callback
end

function broadcast_methods:dismiss(callback)
    local i = nil
    for index, v in ipairs(self[1]) do
        if v == callback then
            i = index
            break
        end
    end
    table.remove(self[1], i)
end

function series_methods:transform(callback)
    local new_series = create()
    self:listen(function(value)
        new_series:put(callback(value))
    end)
    return new_series
end

function series_methods:broadcast()
    local bc = create_broadcast()
    self:listen(function (val)
        bc:put(val)
    end)
    return bc
end

do
    if require "away.promise" then
        local Promise = require "away.promise"
        
        function series_methods:take(condf)
            return Promise.create(function(resolve, reject)
                local values = {}
                local cb
                cb = self:listen(function(val)
                    while condf(val) do
                        values[#values+1] = val
                    end
                    resolve(values)
                    self:dismiss(cb)
                end)
            end)
        end
    end
end

for k, v in pairs(series_methods) do
    if broadcast_methods[k] == nil then
        broadcast_methods[k] = v
    end
end

local mod = {
    create = create,
    create_broadcast = create_broadcast,
}

return mod
