package = "away"
version = "git-0"
source = {
   url = "git+https://github.com/thislight/away.git",
}
description = {
   summary = "A easy by-signal coroutine scheduler for Lua.",
   detailed = [[Away provides a easy by-signal coroutine scheduler for asynchronous programming.]],
   homepage = "https://github.com/thislight/away",
   license = "GPL-3"
}
dependencies = {
   "lua 5.3,5.4"
}
build = {
   type = "builtin",
   modules = {
      away = "away.lua",
      ['away.debugger'] = "away/debugger/init.lua"
   }
}
