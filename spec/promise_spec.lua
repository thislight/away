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

local away = require "away"
local debugger = require "away.debugger"
local mocks = require "away.debugger.mocks"

describe("away.promise", function()
    local Promise = require "away.promise"
    describe("create", function()
        it("can create promise without execfn", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            scheduler:run_task(function()
                Promise.create()
            end)
            scheduler:run()
        end))

        it("will run the function once if execfn given", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local callable_mock_ctl = mocks.callable()
            scheduler:run_task(function()
                Promise.create(callable_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.True(callable_mock_ctl.called, "the callable should be called")
            assert.is.True(callable_mock_ctl.called_count == 1, "the callable should be called once")
        end))

        it("will run the function in scheduler if execfn given", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local current_thread_result
            local function callback()
                current_thread_result = away.get_current_thread() -- use a away call for the in-scheduler testing
            end
            scheduler:run_task(function()
                Promise.create(callback)
            end)
            scheduler:run()
            assert.is.True(type(current_thread_result) == "thread", "the callback should get the current thread from scheduler")
        end))
    end)

    describe("wait", function()
        it("could get the value if the promise resolved", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            scheduler:run_task(function()
                local result = {}
                local promise = Promise.create(function(resolve) resolve(result) end)
                local returnvalue = promise:wait()
                assert.equals(returnvalue, result)
            end)
            scheduler:run()
        end))

        it("could throw the error if the promise rejected", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            scheduler:run_task(function()
                local reason = tostring({})
                local promise = Promise.create(function(resolve, reject) reject(reason) end)
                assert.has_error(function()
                    promise:wait()
                end, reason)
            end)
            scheduler:run()
        end))
    end)

    describe("on_value", function()
        it("could set a callback which only be called once when promise resolved", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local result = {}
            local callback_mock_ctl = mocks.callable(function(v)
                assert.equals(v, result)
            end)
            scheduler:run_task(function()
                local promise = Promise.create(function(resolve) resolve(result) end)
                promise:on_value(callback_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.True(callback_mock_ctl.called)
            assert.equals(callback_mock_ctl.called_count, 1)
        end))

        it("the set callback should not be called when promise rejected", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local callback_mock_ctl = mocks.callable()
            scheduler:run_task(function()
                local promise = Promise.create(function(resolve, reject) reject() end)
                promise:on_value(callback_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.False(callback_mock_ctl.called)
        end))
    end)

    describe("on_err", function()
        it("could set a callback which only be called once when promise rejected", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local result = {}
            local callback_mock_ctl = mocks.callable(function(v)
                assert.equals(v, result)
            end)
            scheduler:run_task(function()
                local promise = Promise.create(function(resolve, reject) reject(result) end)
                promise:on_err(callback_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.True(callback_mock_ctl.called)
            assert.equals(callback_mock_ctl.called_count, 1)
        end))

        it("the set callback should not be called when promise resolved", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local callback_mock_ctl = mocks.callable()
            scheduler:run_task(function()
                local promise = Promise.create(function(resolve) resolve() end)
                promise:on_err(callback_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.False(callback_mock_ctl.called)
        end))

        it("will resolve the chained promise when the callback return a non-nil value", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local rejecting_reason, resolving_result = {}, {}
            local final_callback_mock_ctl = mocks.callable(function(v)
                assert.equals(v, resolving_result)
            end)
            scheduler:run_task(function()
                local promise = Promise.create(function(resolve, reject) reject(rejecting_reason) end)
                promise:on_err(function(v)
                    assert.equals(v, rejecting_reason)
                    return resolving_result
                end)
                :on_value(final_callback_mock_ctl.mock)
            end)
            scheduler:run()
            assert.is.True(final_callback_mock_ctl.called)
        end))
    end)

    describe("all", function()
        it("will resolved with all the result when all promises resolved", debugger:wrapenv(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local defined_results = {}
            local promises = {}
            local results
            scheduler:run_task(function()
                for i=1, 300 do
                    defined_results[i] = {}
                    promises[i] = Promise.create(function(resolve) resolve(defined_results[i]) end)
                end
                local p = Promise.all(promises)
                results = p:wait()
            end)
            scheduler:run()
            for i=1, 300 do
                assert.equals(defined_results[i], results[i], i)
            end
        end))
    end)
end)
