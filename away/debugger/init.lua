local fireline = require("away").fireline

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

return debugger
