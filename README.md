# Away
A easy by-signal coroutine scheduler for Lua.

Known supported version:
- Lua 5.3
- Lua 5.4

Pipeline status:
| Branch  | Status                                                                                                                                                                                                                                         |
|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| master  | [![pipeline status](https://gitlab.com/thislight/away/badges/master/pipeline.svg)](https://gitlab.com/thislight/away/-/pipelines?scope=all&ref=master)![coverage report](https://gitlab.com/thislight/away/badges/master/coverage.svg)    |
| develop | [![pipeline status](https://gitlab.com/thislight/away/badges/develop/pipeline.svg)](https://gitlab.com/thislight/away/-/pipelines?scope=all&ref=develop)![coverage report](https://gitlab.com/thislight/away/badges/develop/coverage.svg) |


## Install Away

````
luarocks install away
````

Or copy the files you need. Away is zero-dependency.

## Current versions
- Developing: 0.1.3
- RR(Release-Ready): 0.1.2
- Stable: COMING SOON

## Drivers
Use away with any other asynchronous-programming library.

- [away-luv](https://github.com/thislight/away-luv)

## Helpers

- [away-dataqueue](https://github.com/thislight/away-dataqueue)

## Doucments
- [Designs](wiki/designs.md)
- [Usage](wiki/usage.md)
- [Example](example/)
- [Contribution Guide](wiki/contribution.md)

## Run Tests
Tests use [busted](http://olivinelabs.com/busted/).
To run tests, just use the command in project directory:
````shell
busted
````

## License
GNU Gerneral Public License, version 3 or later.

    away - a easy by-signal coroutine scheduler for Lua
    Copyright (C) 2020 thisLight <l1589002388@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

> Note on GPLv3: although you have copied code from this project, you don't need to open source if you don't convey it (see GPLv3 for definition of "convey"). This is not a legal advice.

## Special Things

[Earlier Version of This Project](https://gist.github.com/thislight/220ce18f2e7f303c0b08e1e9c6f3c8ae)
