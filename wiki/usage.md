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

### Microtask Service
````lua
local away = require "away"
local mtask_serv = away.scheduler:install(away.microtask_service)
local schedule_microtask = mtask_serv:make_schedule_function()

schdule_microtask(function() print("Hello World") end)

away.scheduler:run()
````

#### `microtask_service.install(self, scheduler)`
When you call `scheduler:install` on microtask service, it will call this function and return the result.
Return a copied `microtask_service`, which is a really usable object.

#### `microtask_service.clone_to(self, new_t)`
Copy values in `self` to `new_t`.
Return `new_t`.

#### `microtask_service.schedule_microtask(self, taskf)`
Schedule the run of `taskf`. The function just push a signal to run the thread of microtask service.

#### `microtask_service.make_schedule_function(self)`
Return a `function` which with one parameter `taskf` to call `self:schedule_microtask(taskf)`.