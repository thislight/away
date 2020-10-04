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
describe("away.debugger", function()
    local away = require "away"
    local debugger = require "away.debugger"

    describe("set_timeout()", function()
        it("can throw error after timeout", function()
            debugger:new_environment(function(scheduler, debugger)
                local watchers = debugger:set_timeout(scheduler, 1)
                local empty_thread = coroutine.create(
                                         function()
                        while true do coroutine.yield() end
                    end)
                scheduler:set_auto_signal(
                    function()
                        return {target_thread = empty_thread}
                    end)
                assert.has_error(function() scheduler:run() end, "timeout")
            end)
        end)
    end)
end)
