-- Copyright 2020-2022 thisLight.
-- SPDX-License-Identifier: GPL-3.0-or-later

local fireline = require("away").fireline
local scheduler = require("away").scheduler

local debugger = {
    recent_threads = {},
    max_tid = 0,
}

local function topstring(t)
    if type(t) == 'table' then
        local buffer =  {}
        for k,v in pairs(t) do
            table.insert(buffer, string.format("%s=%s", topstring(k), topstring(v)))
        end
        return '{'..table.concat(buffer, ',')..'}'
    elseif type(t) == 'string' then
        return '"'..t..'"'
    elseif type(t) == 'number' then
        return tostring(t)
    else
        return '<'..tostring(t)..'>'
    end
end

function debugger:create(t)
    t = t or {}
    for k, v in pairs(self) do
        t[k] = v
    end
    t.recent_threads = {}
    t.max_tid = 0
    return t
end

function debugger:cleanup()
    self.recent_threads = {}
    self.max_tid = 0
end

debugger.topstring = topstring

function debugger:remap_thread(thread)
    if not self.recent_threads[thread] then
        self.max_tid = self.max_tid + 1
        self.recent_threads[thread] = self.max_tid
        return self.max_tid
    else
        return self.recent_threads[thread]
    end
end

function debugger:all_recent_threads()
    return coroutine.wrap(function()
        for thread, id in pairs(self.recent_threads) do
            coroutine.yield(thread, id)
        end
    end)
end

function debugger:pretty_signal(sig)
    local copy = {}
    for k,v in pairs(sig) do
        if type(v) == 'thread' then
            copy[k] = self:remap_thread(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function debugger:pretty_signal_queue(queue)
    local copy = {}
    local insert = table.insert
    for _, v in ipairs(queue) do
        insert(copy, self:pretty_signal(v))
    end
    return copy
end

function debugger:set_default_watchers(scheduler, out)
    out = out or print
    return {
        push_signal = scheduler:add_watcher('push_signal', function(_, signal, index) out("push_signal", index, self.topstring(self:pretty_signal(signal))) end),
        run_thread = scheduler:add_watcher('run_thread', function(_, thread, signal) out("run_thread", self:remap_thread(thread), self.topstring(self:pretty_signal(signal))) end),
        before_run_step = scheduler:add_watcher('before_run_step', function(_, signal_queue) out("before_run_step", self.topstring(self:pretty_signal_queue(signal_queue))) end),
        set_auto_signal = scheduler:add_watcher('set_auto_signal', function(_, autosig_gen, fst_sig) out("set_auto_signal", autosig_gen, self.topstring(self:pretty_signal(fst_sig))) end),
    }
end

function debugger:unset_default_watchers(scheduler, d)
    for k, v in pairs(d) do
        fireline.remove_by_value(scheduler.watchers[k], v)
    end
end

function debugger:set_thread_jump_recorder(scheduler)
    local records = {}
    local watchers = {
        run_thread = scheduler:add_watcher('run_thread', function(_, thread, signal)
            table.insert(records, {
                source = signal.source_thread,
                target = thread
            })
        end)
    }
    return records, watchers
end

function debugger:unset_watchers(scheduler, d)
    self:unset_default_watchers(scheduler, d)
end

local function group_by(t, key)
    local result = {}
    for i, v in ipairs(t) do
        if not result[key] then
            result[key] = {}
        end
        table.insert(result[key], v)
    end
    return result
end

function debugger:set_target_thread_uniqueness_checker(scheduler, errout)
    errout = errout or error
    local watchers = {
        before_run_step = scheduler:add_watcher('before_run_step', function(_, signalq)
            local groups = group_by(signalq, 'target_thread')
            for th, signals in pairs(groups) do
                if #signals > 1 then
                    errout(string.format("targeted thread %d (%s) is not unique in one pass of scheduler loop: %s", self:remap_thread(th), th, self.topstring(self:pretty_signal_queue(signals))), 2)
                end
            end
        end)
    }
    return watchers
end

function debugger:set_signal_uniqueness_checker(scheduler, errout)
    errout = errout or error
    local watchers = {
        push_signal = scheduler:add_watcher('push_signal', function(scheduler, signal)
            local signalq = scheduler.signal_queue
            for _, sig in ipairs(signalq) do
                if sig == signal then
                    errout("signal could not be inserted twice or more : "..self.topstring(self:pretty_signal(sig)), 2)
                end
            end
        end)
    }
    return watchers
end

function debugger:new_environment(func)
    local new_scheduler = scheduler:clone_to {}
    local new_debugger = self:create()
    return func(new_scheduler, new_debugger)
end

function debugger:wrapenv(func)
    return function()
        debugger:new_environment(func)
    end
end

function debugger:set_timeout(scheduler, timeout, errout, timeprovider)
    errout = errout or error
    timeprovider = timeprovider or os.time
    local promised_time = timeprovider() + timeout
    local watchers = {
        before_run_step = scheduler:add_watcher('before_run_step', function()
            if timeprovider() >= promised_time then
                errout("timeout")
            end
        end),
    }
    return watchers
end

function debugger:is_next_signal_match(scheduler, pattern, pos)
    local queue = scheduler.signal_queue
    pos = pos or 1
    if pos < 0 then
        pos = #queue - (pos + 1)
    end
    local target_signal = queue[pos]
    for k, v in pairs(pattern) do
        if target_signal[k] ~= v then
            return false
        end
    end
    return true
end

local ddebug = {}
debugger.debug = ddebug

local function el_exists(t, el)
    for _, v in ipairs(t) do
        if v == el then
            return true
        end
    end
    return false
end

function ddebug.sethook(scheduler, hook, mask, count)
    local threads = {}
    local watchers = {
        run_thread = scheduler:set_watcher('run_thread', function(scheduler, thread, signal)
            if not el_exists(threads, thread) then
                local function hook_warpper(event, lineno)
                    hook(event, lineno, scheduler, thread)
                end
                debug.sethook(thread, hook_warpper, mask, count)
                table.insert(threads, thread)
            end
        end)
    }
    return watchers
end

return debugger
