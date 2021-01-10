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

local fireline = {}

function fireline.create()
    local new_t = {}
    setmetatable(new_t, {
        __call = function(self, ...)
            for _, f in ipairs(new_t) do
                f(...)
            end
        end
    })
    return new_t
end

function fireline.copy(fl)
    local new_fl = fireline.create()
    table.move(fl, 1, #fl, 1, new_fl)
    return new_fl
end

function fireline.append(fl, val)
    table.insert(fl, val)
    return val
end

function fireline.remove_by_value(fl, value)
    local index
    for i, v in ipairs(fl) do
        if value == v then
            index = i
        end
    end
    if index then
        table.remove(fl, index)
    end
    return index
end

local threadpool = {}

local function threadpool_body(descriptor, pool)
    local fn, pack, unpack
    pack = table.pack
    unpack = table.unpack
    while true do
        descriptor.state = 'waiting'
        if not fn then
            fn = co.yield()
        end
        if type(fn) == 'table' then
            fn = fn.threadpool_callback
        end
        if type(fn) == 'function' then
            descriptor.state = 'running'
            local run = fn
            fn = nil
            local result = pack(run())
            table.insert(pool, descriptor)
            fn = co.yield(unpack(result))
        end
    end
end

function threadpool.new()
    return table_deep_copy(threadpool, {})
end

function threadpool:create_executor()
    local descriptor = {}
    local new_thread = co.create(threadpool_body)
    descriptor.thread = new_thread
    co.resume(new_thread, descriptor, self)
    table.insert(self, descriptor)
    return descriptor
end

function threadpool:first_waiting_executor()
    for i, v in ipairs(self) do
        if v.state == 'waiting' and co.status(v.thread) ~= 'dead' then
            return table.remove(self, i)
        end
    end
end

function threadpool:runfn(fn, resume)
    resume = resume or co.resume
    local waiting_executor = self:first_waiting_executor()
    if not waiting_executor then
        waiting_executor = self:create_executor()
    end
    waiting_executor.state = 'scheduled'
    resume(waiting_executor.thread, fn)
    return waiting_executor
end

local scheduler = {
    signal_queue = {},
    auto_signals = {},
    current_thread = nil,
    stop_flag = false,
    error_handler = function(scheduler, err, thread, signal)
        if debug then
            local traceback = debug.traceback(thread, err)
            error(traceback)
        else
            error(string.format("user thread error: %s", err))
        end
    end,
    watchers = {
        run_thread = fireline.create(), -- function(scheduler, thread, signal) end
        push_signal = fireline.create(),-- function(scheduler, signal, index) end
        before_run_step = fireline.create(),-- function(scheduler, signal_queue) end
        set_auto_signal = fireline.create(),-- function(scheduler, autosig_gen, first_signal) end
    },
    timed_events = {},
    timers = {},
    time = function()
        return os.time() * 1000
    end,
    threadpool = threadpool.new(),
}

function scheduler:clone_to(new_t)
    table_deep_copy(self, new_t)
    for k, v in pairs(new_t.watchers) do
        new_t.watchers[k] = fireline.copy(v)
    end
    return new_t
end

function scheduler.new()
    local newobj = {}
    scheduler:clone_to(newobj)
    return newobj
end

local function timed_events_find_next_slot(t, event)
    for index, ev in ipairs(t) do
        if ev.promised_time < event.promised_time then
            return index + 1
        end
    end
    return #t + 1
end

local function timer2event(timer, base_time)
    if timer.type == 'once' then
        return {
            promised_time = base_time + timer.delay,
            callback = timer.callback,
            timer = timer,
        }
    elseif timer.type == 'repeat' then
        return {
            promised_time = base_time + timer.duration,
            callback = timer.callback,
            timer = timer,
        }
    end
end

function scheduler:set_timer(options)
    options.type = options.type or 'once'
    if options.type == 'once' then
        assert(options.delay ~= nil)
        assert(options.callback)
        local event = timer2event(options, self.time())
        local index = timed_events_find_next_slot(self.timed_events, event)
        table.insert(self.timed_events, index, event)
    elseif options.type == 'repeat' then
        assert(options.duration ~= nil)
        assert(options.callback)
        options.start_time = self.time()
        options.epoch = 0
        table.insert(self.timers, options)
    else
        error('type must one of "once" and "repeat", got '..options.type)
    end
end

function scheduler:run_callback_in_threadpool(callback, source_thread, index)
    self.threadpool:runfn(callback, function(thread, fn)
        self:push_signal({
            target_thread = thread,
            threadpool_callback = fn,
        }, source_thread, index)
    end)
end

local function insert_timed_event(t, event)
    local index = timed_events_find_next_slot(t, event)
    table.insert(t, index, event)
end

function scheduler:scan_timers(current_time)
    local to_be_remove_indexs = {}
    for i, timer in ipairs(self.timers) do
        if timer.cancel then
            table.insert(to_be_remove_indexs, i)
        end
        if timer.type == 'repeat' then
            if current_time >= (timer.start_time + timer.epoch * timer.duration) then
                insert_timed_event(self.timed_events, timer2event(timer))
                timer.epoch = timer.epoch + 1
            end
        elseif timer.type == 'once' then
            insert_timed_event(self.timed_events, timer2event(timer))
            table.insert(to_be_remove_indexs, i)
        end
    end
    for _, i in ipairs(to_be_remove_indexs) do
        table.remove(self.timers, i)
    end
end

function scheduler:run_timed_events(current_time)
    local to_be_removed_indexs = {}
    for i, e in ipairs(self.timed_events) do
        if (not e.timer.cancel) and current_time >= e.promised_time then
            self:run_callback_in_threadpool(e.callback, e.timer.source_thread)
            table.insert(to_be_removed_indexs, i)
        else
            break -- the self.timed_events are always sorted by .promised_time
        end
    end
    for _, i in ipairs(to_be_removed_indexs) do
        table.remove(self.timed_events, i)
    end
end

function scheduler:push_signal(signal, source_thread, index)
    assert(signal.target_thread ~= nil, "signal must have field 'target_thread'")
    if not signal.source_thread then
        signal.source_thread = source_thread
    end
    index = index or (#self.signal_queue + 1)
    self.watchers.push_signal(self, signal, index)
    table.insert(self.signal_queue, index, signal)
end

function scheduler:push_signal_to_first(signal, source_thread)
    self:push_signal(signal, source_thread, 1)
end

function scheduler:pop_signal() return table.remove(self.signal_queue, 1) end

function scheduler:install(installer) return installer:install(self) end

function scheduler:set_auto_signal(f)
    assert(type(f) == 'function', 'set_auto_signal must passed a function which return a new signal')
    local first_signal = f()
    if first_signal then
        self:push_signal(first_signal)
    end
    self.watchers.set_auto_signal(self, f, first_signal)
    table.insert(self.auto_signals, f)
end

local function handle_away_call(scheduler, thread, signal)
    local call = signal.away_call
    if call == 'current_thread' then
        scheduler:push_signal_to_first({
            target_thread = thread,
            current_thread = thread,
        }, thread)
    elseif call == 'schedule_thread' then
        local target_thread = signal.target_thread
        local new_thread_sig = signal.mixsignal or {}
        new_thread_sig.target_thread = target_thread
        scheduler:push_signal(new_thread_sig, thread)
        scheduler:push_signal_to_first({
            target_thread = thread,
        }, thread)
    elseif call == 'push_signals' then
        local new_signals = signal.signals
        if new_signals then
            for i, v in ipairs(new_signals) do
                scheduler:push_signal(v)
            end
        end
        scheduler:push_signal_to_first({target_thread = thread}, thread)
    elseif call == 'set_timers' then
        local timers = signal.timers
        for _, v in ipairs(timers) do
            scheduler:set_timer(v)
        end
        scheduler:push_signal_to_first({
            target_thread = thread,
        }, thread)
    elseif call == 'schedule_task' then
        scheduler:run_callback_in_threadpool(signal.task, signal.source_thread)
        scheduler:push_signal_to_first({
            target_thread = thread,
        }, thread)
    end
end

function scheduler:run_thread(thread, signal)
    self.current_thread = thread
    self.watchers.run_thread(self, thread, signal)
    local stat, new_signal = co.resume(thread, signal)
    if stat then
        if new_signal then
            if new_signal.away_call then
                handle_away_call(self, thread, new_signal)
            else
                self:push_signal(new_signal, thread)
            end
        end
    else
        self:error_handler(new_signal, thread, signal)
    end
    self.current_thread = nil
end

function scheduler:run_step()
    local current_time = self.time()
    local queue = {}
    table.move(self.signal_queue, 1, #self.signal_queue, 1, queue)
    self.signal_queue = {}
    self.watchers.before_run_step(self, queue)
    self:scan_timers(current_time)
    self:run_timed_events(current_time)
    for i, signal in ipairs(queue) do
        self:run_thread(signal.target_thread, signal)
    end
    for _, sig_gen in ipairs(self.auto_signals) do
        local sig = sig_gen()
        if sig then
            sig.is_auto_signal = true
            self:push_signal(sig)
        end
    end
end

function scheduler:has_anything_can_do()
    return (#self.signal_queue > 0) or (#self.timed_events > 0) or (#self.timers > 0)
end

function scheduler:run()
    while self:has_anything_can_do() and (not self.stop_flag) do self:run_step() end
end

function scheduler:runforever() while not self.stop_flag do self:run_step() end end

function scheduler:stop() self.stop_flag = true end

function scheduler:cleanup()
    self.signal_queue = {}
    self.auto_signals = {}
    self.timers = {}
    self.timed_events = {}
    self.current_thread = nil
    self.stop_flag = false
end

function scheduler:run_task(taskf)
    self:run_callback_in_threadpool(taskf)
end

function scheduler:add_watcher(name, watcher)
    local target_fireline = self.watchers[name]
    assert(target_fireline, "the targeted watcher name must exists")
    return fireline.append(target_fireline, watcher)
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

local function get_current_thread()
    local sig = co.yield({
        away_call = 'current_thread'
    })
    return sig.current_thread
end

local function schedule_thread(thread, mixsignal)
    co.yield({
        away_call = 'schedule_thread',
        target_thread = thread,
        mixsignal = mixsignal,
    })
end

local function wakeback_later()
    co.yield {
        target_thread = get_current_thread()
    }
end

local function push_signals(signals)
    co.yield {
        away_call = 'push_signals',
        signals = signals
    }
end

local function set_timers(timers)
    co.yield {
        away_call = 'set_timers',
        timers = timers,
    }
end

local function set_timeout(timeout, callback)
    set_timers {
        {
            type = 'once',
            delay = timeout,
            callback = callback,
        }
    }
end

local function sleep(timeout)
    local current_thread = get_current_thread()
    set_timeout(timeout, function()
        schedule_thread(current_thread)
    end)
    co.yield()
end

local function set_repeat(duration, callback)
    set_timers {
        {
            type = 'repeat',
            duration = duration,
            callback = callback,
        }
    }
end

local function schedule_task(fn)
    co.yield {
        task = fn,
        away_call = "schedule_task"
    }
end

return {
    scheduler = scheduler,
    wait_signal_for = wait_signal_for,
    wait_signal_like = wait_signal_like,
    get_current_thread = get_current_thread,
    schedule_thread = schedule_thread,
    wakeback_later = wakeback_later,
    push_signals = push_signals,
    fireline = fireline,
    threadpool = threadpool,
    set_timers = set_timers,
    set_timeout = set_timeout,
    sleep = sleep,
    set_repeat = set_repeat,
    schedule_task = schedule_task,
}
