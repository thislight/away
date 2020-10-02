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
TODO: write document  
You can look at source for now, it's super easy.

#### `scheduler.clone_to(self, new_t)`
Copy key-value pairs from `self` to `new_t`.
Return `new_t`.

#### `scheduler.push_signal(self, signal, source_thread, index)`
Push `signal` into the singal queue of `self`.  
The default `index` is the length of queue plus 1 (end of queue).*new in 0.0.2: parameter index*  
If `signal.source_thread` have not set, the value willl be set as `source_thread`.  
If `signal` doesn't have field `target_thread`, a error will be thrown.

- This function will trigger watcher `push_signal(scheduler, signal, index)`. *new in 0.0.2*

#### `scheduler.push_signal_to_first(self, signal, source_thread)`
*new in 0.0.2*  
Equivent to `scheduler.push_signal(self, signal, source_thread, 1)`. 

#### `scheduler.pop_signal(self)`
Pop a signal from signal queue. Generally do not use this function. Currently, scheduler itself does not use it.
Return the signal.

#### `scheduler.install(self, installer)`
Install a plugin. This function call `installer.install` by scheduler itself.
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
Away call help program reach some scheduler's features without reaching the scheduler. *new in 0.0.2*

- current_thread *new in 0.0.2*
- schedule_thread *new in 0.0.3*
- push_signals *new in 0.0.5*

###### `current_thread`
Resume the calling thread as soon as possible by a signal contains itself (`.current_thread`).

###### `schedule_thread`
Push a empty signal which run the thread given (the signal `.target_thread`). Resume the calling thread as soon as possible.
- If the signal have `.mixsignal`, it will be set `target_thread` and used as the signal sent to queue. *new in 0.0.5*

###### `push_signals`
Push signals from the signal `.signals`, wakeback thread as soon as possible.

#### `scheduler.run(self)`
Start the scheduler loop. Return only when the signal queue is empty or stop flag set (by `.stop()`).

#### `schedule.runforever(self)`
Run the scheduler loop until stop flag set (by `stop()`).
