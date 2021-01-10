-- Copyright (C) 2020 thisLight
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
local mocks = require "away.debugger.mocks"

describe("scheduler", function()
    local away = require "away"
    local debugger = require "away.debugger"
    local co = coroutine

    it("can jump across threads based on signals", function()
        debugger:new_environment(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local thread_mock = mocks.thread()
            scheduler:run_task(function()
                return {target_thread = thread_mock.mock}
            end)
            scheduler:run()
            assert.equals(1, thread_mock.called_count,
                          "the thread must be jumped to once, got " ..
                              thread_mock.called_count)
        end)
    end)
    describe("away call", function()
        it("can handle get_current_thread", function()
            debugger:new_environment(function(scheduler, debugger)
                debugger:set_timeout(scheduler, 10)
                local thread2
                local thread = mocks.thread(
                                   function()
                        thread2 = away.get_current_thread()
                    end)
                scheduler:push_signal{target_thread = thread.mock}
                scheduler:run()
                assert.equals(thread.mock, thread2)
            end)
        end)

        it("can handle schedule_thread", function()
            debugger:new_environment(function(scheduler, debugger)
                debugger:set_timeout(scheduler, 10)
                local thread = mocks.thread()
                scheduler:run_task(function()
                    away.schedule_thread(thread.mock)
                end)
                scheduler:run()
                assert.equals(thread.called_count, 1)
            end)
        end)

        it("can handle push_signals", function()
            debugger:new_environment(function(scheduler, debugger)
                debugger:set_timeout(scheduler, 10)
                local thread = mocks.thread()
                scheduler:run_task(function()
                    away.push_signals({
                        {target_thread = thread.mock},
                        {target_thread = thread.mock}
                    })
                end)
                scheduler:run()
                assert.equals(thread.resume_count, 2)
            end)
        end)
    end)

    it("can use auto signal", function()
        debugger:new_environment(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local countdown = 2
            local thread = mocks.thread(function()
                while countdown > 0 do
                    countdown = countdown - 1
                    co.yield()
                end
                scheduler:stop()
            end)
            scheduler:set_auto_signal(function()
                return {target_thread = thread.mock}
            end)
            scheduler:run()
            assert.equals(0, countdown)
        end)
    end)
end)

describe("wakeback_later()", function()
    local away = require "away"
    local debugger = require "away.debugger"

    it("can wakeback thread correctly", function()
        debugger:new_environment(function(scheduler, debugger)
            debugger:set_timeout(scheduler, 10)
            local reach = false
            local thread = mocks.thread(function()
                away.wakeback_later()
                reach = true
            end)
            scheduler:push_signal{target_thread = thread.mock}
            scheduler:run()
            assert.is.True(reach)
        end)
    end)
end)

describe("timer", function()
    local away = require "away"
    local debugger = require "away.debugger"

    it("set_timer() can set timers",
       debugger:wrapenv(function(scheduler, debugger)
        debugger:set_timeout(scheduler, 3)
        local time = 10
        local reach = false
        scheduler.time = function() return time end
        scheduler:run_task(function()
            away.set_timers {
                {
                    type = 'once',
                    delay = 1000,
                    callback = function() time = 4000 end
                },
                {
                    type = 'once',
                    delay = 3000,
                    callback = function() reach = true end
                }
            }
        end)
        scheduler:run_task(function() time = 1500 end)
        scheduler:run()
        assert.is.True(reach)
    end))

    it("sleep() can let a thread sleep a while",
       debugger:wrapenv(function(scheduler, debugger)
        debugger:set_timeout(scheduler, 3)
        local reach = false
        local time = 0 -- Warning: It's DANGEROUS to use such a trick to control time for scheduler, DO NOT change the value twice.
        -- If you want to change it twice or more, using real world time instead manually controlled will be less confusion
        scheduler.time = function() return time end
        scheduler:run_task(function()
            scheduler:run_task(function()
                assert.is.False(reach)
                time = 5000
            end)
        end)
        scheduler:run_task(function()
            away.sleep(3000)
            reach = true
        end)
        scheduler:run()
        assert.is.True(reach)
    end))
end)

describe("threadpool", function()
    local away = require "away"
    local debugger = require "away.debugger"
    describe("runfn()", function()
        it("can run function when all the threads of executors exists died",
           debugger:wrapenv(function(scheduler, debugger)
            local thread_pool = away.threadpool.new()
            thread_pool:runfn(function()
                error("simulate thread died unexpectedly")
            end)
            local reach = false
            thread_pool:runfn(function() reach = true end)
            assert.is.True(reach, "the second called function should be run")
        end))
    end)
end)
