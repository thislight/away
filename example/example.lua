local away = require "away"
local scheduler = away.scheduler
local microtask_serv_ref = scheduler:install(away.microtask_service)
local schedule_microtask = microtask_serv_ref:make_schedule_function()

local function topstring(t)
    if type(t) == 'table' then
        local buffer =  {}
        for k,v in pairs(t) do
            table.insert(buffer, string.format("%s=%s", topstring(k), topstring(v)))
        end
        return '{'..table.concat(buffer, ',')..'}'
    else
        return tostring(t)
    end
end

local co = coroutine

scheduler:add_watcher('push_signal', function(_, signal) print('signal', topstring(signal)) end)

local the_thread = co.create(function(signal)
    print("called")
    return {name = "World", target_thread = signal.source_thread}
end)

scheduler:run_task(function()
    print("waiting")
    local signal = away.wait_signal_like({target_thread = the_thread}, {
        name = function(v) return type(v) == 'string' end
    })
    print(string.format("Hello %s!", signal.name))
end)

scheduler:run()
