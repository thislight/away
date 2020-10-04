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

    it("can handle get_current_thread away call", function()
        debugger:new_environment(function(scheduler, debugger)
            local thread2
            local thread = mocks.thread(
                function()
                    thread2 = away.get_current_thread()
                end
            )
            scheduler:push_signal {
                target_thread = thread.mock
            }
            scheduler:run()
            assert.equals(thread.mock, thread2)
        end)
    end)

    it("can use auto signal", function()
        debugger:new_environment(function(scheduler, debugger)
            local countdown = 2
            local thread = mocks.thread(
                function()
                    while countdown > 0 do
                        countdown = countdown - 1
                        co.yield()
                    end
                    scheduler:stop()
                end
            )
            scheduler:set_auto_signal(
                function()
                    return {
                        target_thread = thread.mock
                    }
                end
            )
            scheduler:run()
            assert.equals(0, countdown)
        end)
    end)
end)
