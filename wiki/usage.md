<!--
 Copyright (C) 2020 thisLight
 
 This file is part of away.
 
 away is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 away is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with away.  If not, see <http://www.gnu.org/licenses/>.
-->

# Usage

````lua
local away = require "away"
local scheduler = away.scheduler

local co = coroutine

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
````

## API
### Scheduler
#### `scheduler.clone_to(self, new_t)`
Copy key-value pairs from `self` to `new_t`.
Return `new_t`.

#### `scheduler.new()`
Create a new scheduler object. Return scheduler.

#### `scheduler.push_signal(self, signal, source_thread, index)`
Push `signal` into the singal queue of `self`.  
The default `index` is the length of queue plus 1 (end of queue).
If `signal.source_thread` have not set, the value willl be set as `source_thread`.  
If `signal` doesn't have field `target_thread`, a error will be thrown.

- This function will trigger watcher `push_signal(scheduler, signal, index)`. *new in 0.0.2*

*new in 0.0.2: new parameter "index"*  

#### `scheduler.push_signal_to_first(self, signal, source_thread)`
*new in 0.0.2*

Equivent to `scheduler.push_signal(self, signal, source_thread, 1)`. 

#### `scheduler.pop_signal(self)`
Pop a signal from signal queue. Generally do not use this function. Currently, scheduler itself does not use it.
Return the signal.

#### `scheduler.install(self, installer)`
Install a plugin. This function call `installer.install` with scheduler itself.
Return the values return by the calling.

#### `scheduler.set_auto_signal(self, f)`
Add `f` as a auto signal generator. It must return signal or nil every time being called.
The `f` might be called on anytime.

- This function will trigger watcher `set_auto_signal(scheduler, autosig_gen, first_signal)`. *new in 0.0.3*

#### `scheduler.run_thread(self, thread, signal)`
Set `thread` as `current_thread` and run the thread by `signal`.  
This function handling of new signal yielded follow the rules:
- If the signal is `nil` or `false`, skipped.
- If the signal is away call (contain field `away_call`), handle as a away call. *new in 0.0.2*
- Else, push it to signal queue.

If the thread fails, this function thrown a error. Threads must process all acceptable errrors by themselves.

##### Away Calls
*new in 0.0.2*

Away call help program reach some scheduler's features without reaching the scheduler. 

- current_thread *new in 0.0.2*
- schedule_thread *new in 0.0.3*
- push_signals *new in 0.0.5*
- set_timers *new in 0.1.1*
- schedule_task *new in 0.1.1*

###### `current_thread`
Resume the calling thread as soon as possible by a signal contains itself (`.current_thread`).

- *since 0.1.3: the away call will instantly resume the running of calling thread*

###### `schedule_thread`
Push a empty signal which run the thread given (the signal `.target_thread`). Resume the calling thread as soon as possible.
- If the signal have `.mixsignal`, it will be set `target_thread` and used as the signal sent to queue. *new in 0.0.5*

###### `push_signals`
Push signals from the signal `.signals`, wakeback thread as soon as possible.

###### `set_timers`
Set timers from the signal `.timers`. See `:set_timer(timer)` for the details of timer.

###### `schedule_task`
Run function from the signal `.task` in thread pool. Note that if there is no free executor, a new one will be created.


#### `scheduler.set_timer(self, options)`
*new in 0.1.1*

Create a timer depends on `options`.
- If `options.type` is "once", the function will create a `timed_event`.
- If `options.type` is "repeat", the function will create a `timer`.
- Otherwise the function will throw a error

##### Samples
- Set a one-run timer with 3000ms delay
````lua
scheduler:set_timer {
    type = 'once',
    delay = 3000,
    callback = function() print("Hello World") end,
}
````
- Set a repeat timer with 1000ms duration
````lua
scheduler:set_timer {
    type = 'repeat',
    duration = 1000,
    callback = function() print("Hello World") end,
}
````

#### `scheduler.run(self)`
Start the scheduler loop. Return only when the signal queue is empty or stop flag set (by `.stop()`).

- Trigger watcher "stop" when exiting or error happening. *new in 0.1.3*

#### `scheduler.runforever(self)`
Run the scheduler loop until stop flag being set (by `stop()`).

- Trigger watcher "stop" when exiting or error happening. *new in 0.1.3*

#### `scheduler.cleanup(self)`
Clean up data store in scheduler to get ready for next clean run.

#### `scheduler.run_step(self)`
Run one step of scheduler loop.

- It will run timers and timed_events before run signals. *new in 0.1.1*

#### `scheduler.stop(self)`
Mark the scheduler stop.

#### `scheduler.run_task(self, taskf)`
Create a thread using `taskf` and schedule the run.

#### `scheduler.run_callback_in_threadpool(self, callback)`
Run `callback` in built-in thread pool.

#### `scheduler.add_watcher(self, name, watcher)`
Set a `watcher` for `name`. Return `watcher`.

##### Watchers
- run_thread(scheduler, thread, signal)
- push_signal(scheduler, signal, index)
- before_run_step(scheduler, signal_queue)
- set_auto_signal(scheduler, autosig_gen, first_signal)
- stop(scheduler) *new in 0.1.3*


#### `scheduler.set_poll(self, poller)`
*since 0.1.3*

The the only poller of scheduler. If one poller already set, throw an error.

````lua
-- a sample poller
local function poller(next_event_duration)
    sth.wait_for_duration(next_event_duration)
end
````

#### `scheduler.poll(self, current_time)`
*since 0.1.3*

Call poller once.

This function will automatically called in scheduler running, after auto signals.


#### `scheduler.handle_new_signal(self, new_signal, source_thread)`
*since 0.1.3*

Handle `new_signal` from `source_thread`. The `new_signal` may be a away call or a normal signal.


### Helpers
These helpers are in `away` namespace, most of them are away calls' shortcuts. Away calls require the thread is run by scheduler.

````lua
local away = require "away"

away.scheduler:run_task(function()
    print(away.get_current_thread())
end)
````

#### `get_current_thread()`
*new in 0.0.2*  

Away call `get_current_thread`, return the current thread is in.

#### `schedule_thread(thread, mixsignal)`
*new in 0.0.3*  

Away call to schedule the run of `thread` as `schedule_thread`.
- If `mixsignal` is not `nil` or `false`, it will be sent to the thread as the signal (See section "Away Calls"). *new in 0.0.5*

#### `push_signals(t)`
*new in 0.0.5*  

Away call to push any signals to signal queue as `push_signals`.

#### `wait_signal_for(sig, matchfunc)`
Yield `sig` and wait for a `signal` let `matchfunc(signal)` return truthy value. Return the signal.  
The `sig` only is yielded once.

#### `wait_signal_like(sig, pattern, strict)`
Yield `sig` and wait for a signal matchs `pattern`. `pattern` is a table which will be compared to received signals by key-value pairs. If `strict` is `false`, a function value in `pattern` will be deal as a matcher (a function accept one parameter for the value of the signal), the comparing result of the key-value pair is the result of the function call result; otherwise, every key-value pair will be compared by equal operator (`==`).  
This function will hold (the thread will be yielded) until every key-value pairs in pattern are equal to received signal. Return the signal.  
The `sig` only is yielded once.
````lua
wait_signal_like(nil, {
    kind = "dataqueue_wakeback"
})
````

#### `set_timers(timer_list)`
*new in 0.1.1*

Away call to `set_timers`, the tables in table `timer_list` will be set as timers. Return the list you pass in the function. 

````lua
local away = require "away"

away.scheduler:run_task(function()
    away.set_timers {
        {
            type = 'once',
            delay = 1000,
            callback = function() print("Hello 1") end,
        },
        {
            type = 'once',
            delay = 2000,
            callback = function() print("Hello 2") end,
        }
    }
end)
````

*new in 0.1.2: the function will return the argument instead nothing*
#### `set_timeout(timeout, fn)`
*new in 0.1.1*

Set a timer to run `fn` after `timeout`ms. Return the timer.

````lua
set_timeout(1000, function() print("Hello World") end)
````

*new in 0.1.2: return the timer instead nothing*

#### `sleep(time)`
*new in 0.1.1*

Make current thread sleep `time`ms.

#### `set_repeat(duration, fn)`
*new in 0.1.1*

Run `fn` every `duration`ms. Return the timer. 

*new in 0.1.2: return the timer instead nothing*

#### `schedule_task(fn)`
*new in 0.1.1*

Schedule `fn` to be run in thread pool.

### Fireline
*new in 0.1.0*

Fireline is a small helper library to deal with watcher. It provides a callable table can call all functions in it directly.
````lua
local fireline = require("away").fireline
local fl = fireline.create()
local function spam(name)
    print("Hello, "..name)
end
fireline.append(fl, spam)
fireline.append(fl, spam)
fireline.append(fl, spam)
fl("World")
````

#### `fireline.create()`
Create a fireline. Return a table which can be called directly.

#### `fireline.copy(fl)`
Return a copy of `fl`.

#### `fireline.append(fl, value)`
Insert `value` at the last of `fl`. It is a alias of `table.insert(fl, value)`. Return `value`.

#### `fireline.remove_by_value(fl, value)`
Remove `value` from `fl`. Return a number for the original index, or nil for value not found.


### threadpool
*new in 0.1.1*

Thread pool keeps a set of threads, which can run functions directly, to save time on creating new threads.

````lua
local threadpool = require("away").threadpool
````

#### threadpool.new()
Return a new `ThreadPool` object.

#### threadpool.runfn(self, fn, resume)
Run `fn` in a "waiting" executor. If there is no one executor is waiting, this function will create one.
`resume` is used to resume the executor thread, by default it's `coroutine.resume`.

Return executor descriptor and a table of result of the first resuming (the whole result from the resume function. In the default `coroutine.resume`, the first element is boolean about the running status). Note: This method returns value after one `resume`, so it could not be promised that the executor must in "running" stage if you check it after this method returned. Keep in mind that your program is still running in single native thread.

- *since 0.1.3: return the result table of the first resuming*

#### threadpool.create_executor(self)
Create a new executor and store it in `self`.

Executors have three states:
- `waiting` for executors are not running any function
- `scheduled` for executors are set to run function
- `running` for executors are in function's run

Tips: the executors' state is not the state of if a thread running, it's the state of if the thread is in one user function's stage.

*new in 0.1.2: this method won't return the descriptor*

#### threadpool.remove_avaliable_executor(self)
*new in 0.1.2*

Return & remove the descriptor (table) of the first avaliable executor. Return `nil` when no avaliable executor.

Note: If you use `threadpool.first_waiting_executor` before, use this method instead.

### Debugger
Debugger contains some helpers to help debugging.
````lua
local away = require "away"
local Debugger = require "away.debugger"

Debugger:set_default_watchers(away.scheduler)
Debugger:set_target_thread_uniqueness_checker(away.scheduler)
Debugger:set_signal_uniqueness_checker(away.scheduler)
````
