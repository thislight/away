
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

return debugger
