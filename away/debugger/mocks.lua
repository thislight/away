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

local function callable(extra)
    local info = {
        called = false,
        called_count = 0
    }
    local f = function(...)
        info.called = true
        info.called_count = info.called_count + 1
        if extra then
            return extra(...)
        end
    end
    info.mock = f
    return info
end

local function thread(extra)
    local info
    info = callable(function()
        while true do
            info.resume_count = info.resume_count + 1
            if extra then
                extra()
            end
            coroutine.yield()
        end
    end)
    info.resume_count = 0
    local th = coroutine.create(info.mock)
    info.mock = th
    return info
end

return {
    thread = thread,
    callable = callable,
}
