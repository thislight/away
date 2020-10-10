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
            local thread = mocks.thread(
                function()
                    away.wakeback_later()
                    reach = true
                end
            )
            scheduler:push_signal {target_thread = thread.mock}
            scheduler:run()
            assert.is.True(reach)
        end)
    end)
end)
