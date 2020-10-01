local away = require "away"
local debugger = require "away.debugger"
local scheduler = away.scheduler

local co = coroutine

scheduler:add_watcher('push_signal', function(_, signal) print('signal', debugger.topstring(debugger:pretty_signal(signal))) end)

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
