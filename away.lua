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

local co = coroutine

local scheduler = {
    signal_queue = {},
    auto_signals = {},
    current_thread = nil,
    stop_flag = false
}

local function table_deep_copy(t1, t2)
    for k, v in pairs(t1) do
        if type(v) == 'table' then
            t2[k] = table_deep_copy(v, {})
        else
            t2[k] = v
        end
    end
    return t2
end

function scheduler:clone_to(new_t) return table_deep_copy(self, new_t) end

function scheduler:push_signal(signal, source_thread)
    assert(signal.target_thread ~= nil, "signal must have field 'target_thread'")
    if not signal.source_thread then
        signal.source_thread = source_thread
    end
    table.insert(self.signal_queue, signal)
end

function scheduler:pop_signal() return table.remove(self.signal_queue, 1) end

function scheduler:install(installer) return installer:install(self) end

function scheduler:set_auto_signal(f)
    assert(type(f) == 'function', 'set_auto_signal must passed a function which return a new signal')
    self:push_signal(f())
    table.insert(self.auto_signals, f)
end

function scheduler:run_thread(thread, signal)
    self.current_thread = thread
    local stat, new_signal = co.resume(thread, signal)
    if stat then
        if new_signal then self:push_signal(new_signal, thread) end
    else
        if debug then
            local traceback = debug.traceback(thread, new_signal)
            error(traceback)
        else
            error(string.format("thread error: %s", new_signal))
        end
    end
    self.current_thread = nil
end

function scheduler:run_step()
    local queue = {}
    table.move(self.signal_queue, 1, #self.signal_queue, 1, queue)
    self.signal_queue = {}
    for i, signal in ipairs(queue) do
        self:run_thread(signal.target_thread, signal)
    end
    for _, sig_gen in ipairs(self.auto_signals) do
        self:push_signal(sig_gen())
    end
end

function scheduler:run()
    while #self.signal_queue > 0 and (not self.stop_flag) do self:run_step() end
end

function scheduler:runforever() while not self.stop_flag do self:run_step() end end

function scheduler:stop() self.stop_flag = true end

function scheduler:cleanup()
    self.signal_queue = {}
    self.auto_signals ={}
    self.current_thread = nil
    self.stop_flag = false
end

function scheduler:run_task(taskf)
    local th = co.create(taskf)
    self:run_thread(th)
end

local function wait_signal_for(sig, matchfunc)
    local yielded_sig = sig
    while true do
        local signal = co.yield(yielded_sig)
        yielded_sig = nil
        if matchfunc(signal) then return signal end
    end
end

local function wait_signal_like(sig, pattern, strict)
    return wait_signal_for(sig, function(signal)
        for k, check in pairs(pattern) do
            if not strict and (type(check) == 'function') then
                if not check(signal[k]) then return false end
            else
                if pattern[k] ~= signal[k] then return false end
            end
        end
        return true
    end)
end

local microtask_service = {}

function microtask_service:clone_to(new_t) return table_deep_copy(self, new_t) end

function microtask_service:install(scheduler)
    local new_mtask_serv = self:clone_to{
        scheduler = scheduler,
        thread = self:make_microtask_thread()
    }
    return new_mtask_serv
end

microtask_service.thread_body = function(self)
    while true do
        local signal = co.yield()
        local stat, err = pcall(signal.microtask)
        if not stat then
            if debug and signal.source_thread then
                local traceback = debug.traceback(signal.source_thread, err)
                error(traceback)
            else
                error(string.format("mircotask error: %s", err))
            end
        end
    end
end

function microtask_service:make_microtask_thread()
    local thread = co.create(self.thread_body)
    co.resume(thread, self)
    return thread
end

function microtask_service:schedule_microtask(taskf)
    self.scheduler:push_signal{
        target_thread = self.thread,
        microtask = taskf,
        source_thread = self.scheduler.current_thread
    }
end

function microtask_service:make_schedule_function()
    return function(taskf) self:schedule_microtask(taskf) end
end

return {
    scheduler = scheduler,
    wait_signal_for = wait_signal_for,
    wait_signal_like = wait_signal_like,
    microtask_service = microtask_service
}
