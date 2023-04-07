-- Copyright (C) 2020-2023 thisLight
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
local spy = require "luassert.spy"
describe("away", function()
    local away = require "away"

    describe("sched()", function()
        it("create new scheduler", function()
            local sched = away.sched()
            assert(sched ~= nil)
        end)
    end)

    describe("spawn()", function()
        it("spawn new thread", function()
            local sched = away.sched()
            local th = away.spawn(sched, function() end)
            assert.is_thread(th)
        end)
    end)

    describe("run() and stop()", function()
        it("starts and stops scheduler", function()
            local sched = away.sched()
            local touched = false
            away.spawn(sched, function()
                touched = true;
                away.stop(sched)
            end)
            away.run(sched)
            assert.is_True(touched)
        end)
    end)

    describe("set_timer()", function()
        it("can resume thread 10ms later", function()
            local sched = away.sched()
            local touched = false
            away.spawn(sched, function()
                local t0sec, t0nsec = away.hrt_now()
                local t0 = t0sec * 1000 + t0nsec / 1000
                away.set_timer(10)
                away.yield()
                local t1sec, t1nsec = away.hrt_now()
                local t1 = t1sec * 1000 + t1nsec / 1000
                assert(t1 >= (t0 + 10))
                touched = true
                away.stop(sched)
            end)
            away.spawn(sched, function() end)
            away.run(sched)
            assert.is_True(touched)
        end)
    end)

    describe("switchto()", function()
        it("can set the thread next run", function()
            local sched = away.sched()
            local order = {}
            local th1, th3
            th1 = away.spawn(sched, function()
                order[#order + 1] = 1
                away.switchto(th3)
                away.yield()
            end)
            away.spawn(sched, function() order[#order + 1] = 2 end)
            th3 = away.spawn(sched, function()
                order[#order + 1] = 3
                away.stop(sched)
            end)
            away.run(sched)
            assert.are.same({1, 3, 2}, order)
        end)
    end)

    describe("pause()", function()
        it("can pause the thread from next run", function()
            local sched = away.sched()
            local touched = false
            away.spawn(sched, function()
                away.pause()
                away.yield()
                touched = true
            end)
            away.spawn(sched, function() away.stop(sched) end)
            away.run(sched)
            assert.is_False(touched)
        end)

        it("does not pause the thread immediately", function()
            local sched = away.sched()
            local touched = false
            away.spawn(sched, function()
                away.pause()
                touched = true
            end)
            away.spawn(sched, function() away.stop(sched) end)
            away.run(sched)
            assert.is_True(touched)
        end)
    end)
end)
