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

# Designs
This library must provide a simple scheduler with a fair signal queue. The scheduler call `coroutine.resume` on each signal and push the new signal coroutine yielded to the queue.

## Fair Signal Queue
Mostly, any asynchronous library is used for I/O programming in real life. But it's hard for away, which designed to be implemented by pure lua. Then the only choice is to use a fair signal queue, which treat every signal equally, to offer better friendly interface to other library.

### Auto Signal
Auto signal provides a way to wake a thread on every "step" start. `scheduler.set_auto_signal` in fact add the function given to `scheduler.auto_signals`. The function called auto signal generator, which return a new signal (a table) every single time.

### Self-contain target
You may noticed that the scheduler doesn't keep references to threads. Instead, it requires program provide the target thread every time when you push signal. Keep references in scheduler is bad and make gc sad.

## Threads
To run a thread, the scheduler will `resume` it with a signal and push the value it yielded/returned into signal queue if it's a table. If the table could not be considered as a signal, `push_signal` will call `error`. More details see `scheduler.run_thread`.

### Schedule Threads
For every start of a "step" of the scheduler, it copy all the signal currently have to another internal table, then reset the public queue. In the step, it only walk on these signal it copied. It's for fair of the auto signals. After signals walked, it run all auto signal generators and push them into queue.
