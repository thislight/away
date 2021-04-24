
local enum threadpool_executor_state
    "waiting"
    "running"
end

local record threadpool_executor
    thread: thread
    state: threadpool_executor_state
end

local record threadpool
    {threadpool_executor}
    new: function(): threadpool
    create_executor: function(self: threadpool): nil
    remove_avaliable_executor: function(self: threadpool): threadpool_executor
    first_waiting_executor: function(self: threadpool): threadpool_executor
    run_fn: function(self: threadpool, fn: function, resume: function(thread: thread, fn: function)): threadpool_executor, {any}
end

local type fireline_table = {function}

local record fireline
    create: function(): fireline_table
    copy: function(fl: fireline_table): fireline_table
    append: function(fl: fireline_table, val: function): function
    remove_by_value: function(fl: fireline_table, value: function): integer
end

local enum supported_watcher_key
    "run_thread"
    "push_signal"
    "before_run_step"
    "set_auto_signal"
    "stop"
end 

local record scheduler
    signal_queue: {table}
    auto_signals: {function(): table}
    current_thread: thread | nil
    stop_flag: boolean
    error_handler: function(scheduler, string, thread, signal: table) : nil
    watchers: {string: fireline_table}
    timed_events: {table}
    timers: {table}
    time: function(): integer
    threadpool: threadpool
    poller: function(integer): nil

    clone_to: function(self: scheduler, new_t: table): scheduler
    new: function(self: scheduler): scheduler
    set_timer: function(self: scheduler, options: table): nil
    run_callback_in_threadpool: function(self: scheduler, callback: (function(): nil), source_thread: thread, index: integer | nil): nil
    scan_timers: function(self: scheduler, current_time: integer): nil
    run_timed_events: function(self: scheduler, current_time: integer): nil
    push_signal: function(self: scheduler, signal: table, source_thread: thread, index: integer | nil): nil
    push_signal_to_first: function(self: scheduler, signal: table, source_thread: thread): nil
    pop_signal: function(self: scheduler): table
    install: function(self: scheduler, installer: table): any...
    set_auto_signal: function(self: scheduler, f: (function(): table)): nil
    handle_new_signal: function(self: scheduler, new_signal: table, source_thread: thread): nil
    run_thread: function(self: scheduler, thread: thread, signal: table): nil
    set_poller: function(self: scheduler, poller: (function(integer): nil)): nil
    poll: function(self: scheduler, current_time: integer): nil
    run_step: function(self: scheduler): nil
    has_anything_can_do: function(self: scheduler): boolean
    run: function(self: scheduler): nil
    runforever: function(self: scheduler): nil
    stop: function(self: scheduler): nil
    cleanup: function(self: scheduler): nil
    run_task: function(self: scheduler, taskf: function(): nil): nil
    add_watcher: function(self: scheduler, name: supported_watcher_key, watcher: function): function
end

local record away
    scheduler: scheduler
    threadpool: threadpool
    fireline: fireline
    wait_signal_like: function(sig: table, pattern: table, strict: boolean): table
    get_current_thread: function(): thread
    schedule_thread: function(thread: thread, mixsignal: table|nil): nil
    wakeback_later: function(): nil
    push_signals: function(signals: {table}): nil
    set_timers: function(timers: {table}): {table}
    set_timeout: function(timeout: integer, callback: function(): nil): table
    sleep: function(timeout: integer): nil
    set_repeat: function(duration: integer, callback: function(): nil): table
    schedule_task: function(fn: function(): nil): nil
end

return away
