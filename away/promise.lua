-- Copyright (C) 2021-2022 thisLight
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

local away = require "away"

local promise_object_id = {}

local promise_methods = {}

promise_methods.object_id = promise_object_id

local function do_wakeback_threads(threads)
    for i, v in ipairs(threads) do
        away.schedule_thread(v, {from_promise=true})
    end
end

function promise_methods:resolve(val)
    assert(not self.fulfilled, "promise could not be fulfilled twice")
    self.fulfilled = true
    self.fulfilled_status = 'resolved'
    self.value = val
    do_wakeback_threads(self.wakeback_threads)
end

function promise_methods:reject(err)
    assert(not self.fulfilled, "promise could not be fulfilled twice")
    self.fulfilled = true
    self.fulfilled_status ='rejected'
    self.error = err
    do_wakeback_threads(self.wakeback_threads)
end

function promise_methods:resolvedp()
    return self.fulfilled_status == 'resolved'
end

function promise_methods:rejectedp()
    return self.fulfilled_status == 'rejected'
end

function promise_methods:expose()
    assert(self.fulfilled, "expose() should be called after promise fullfilled")
    if self.value then
        return self.value
    elseif self.error then
        error(self.error)
    else
        error("the promise is invalid")
    end
end

function promise_methods:wait()
    self:just_wait()
    return self:expose()
end

function promise_methods:just_wait()
    if not self.fulfilled then
        self.wakeback_threads[#self.wakeback_threads+1] = away.get_current_thread()
        local sig = coroutine.yield()
        assert(sig.from_promise, "this thread should be wakeback by promise")
    end
end

local function warp_self(self, fn)
    return function(...)
        return fn(self, ...)
    end
end

local function create(execfn)
    local new_t = {
        fulfilled = false,
        fulfilled_status = nil,
        wakeback_threads = {},
    }
    setmetatable(new_t, {__index = promise_methods})
    if execfn then
        local resolve, reject = warp_self(new_t, new_t.resolve), warp_self(new_t, new_t.reject)
        away.schedule_task(function()
            local stat, err = pcall(execfn, resolve, reject, new_t)
            if not stat then
                reject(err)
            end
        end)
    end
    return new_t
end

local function is(obj)
    return type(obj) == 'table' and obj.object_id == promise_object_id
end

function promise_methods:map(fn)
    return create(function(resolve)
        local value = self:wait()
        resolve((fn(value)))
    end)
end

function promise_methods:flatmap(fn)
    return create(function (resolve, reject)
        local value = self:wait()
        if is(value) then
            value:flatmap(fn):map(resolve):maperr(reject)
        else
            resolve((fn(value)))
        end
    end)
end

if pcall(require, "away.series") then
    local Series = require "away.series"

    function promise_methods:as_series()
        local series = Series.create()
        self:map(function (val)
            series:put(val)
        end)
        return series
    end
end

function promise_methods:maperr(fn)
    return create(function(resolve, reject)
        self:just_wait()
        if self:rejectedp() then
            local result = fn(self.error)
            if result ~= nil then
                resolve(result)
            else
                reject(self.error)
            end
        elseif self:resolvedp() then
            resolve(self.value)
        else
            error("this branch should not be reached")
        end
    end)
end

local function all(t)
    return create(function(resolve)
        local results = {}
        for i, v in ipairs(t) do
            local value = v:wait()
            results[#results+1] = value
        end
        resolve(results)
    end)
end

local function race(t)
    return create(function(resolve, reject, promise)
        local err
        local countdown = #t
        for i, v in ipairs(t) do
            v:map(function(val)
                countdown = countdown - 1
                if not promise.fullfilled then
                    resolve(val)
                end
            end)
            v:maperr(function(val)
                countdown = countdown - 1
                err = val
                if countdown <= 0 and not promise.fullfilled then
                    reject(err)
                end
            end)
        end
    end)
end

return {
    create = create,
    resolve = promise_methods.resolve,
    reject = promise_methods.reject,
    wait = promise_methods.wait,
    just_wait = promise_methods.just_wait,
    map = promise_methods.map,
    maperr = promise_methods.maperr,
    all = all,
    race = race,
    rejectedp = promise_methods.rejectedp,
    resolvedp = promise_methods.resolvedp,
    is = is,
    as_series = promise_methods.as_series,
}
