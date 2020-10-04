local away = require "away"
local debugger = require "away.debugger"
local scheduler = away.scheduler

local co = coroutine

debugger:set_default_watchers(scheduler)
debugger:set_signal_uniqueness_checker(scheduler)
debugger:set_target_thread_uniqueness_checker(scheduler)

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
