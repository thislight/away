package = "away"
version = "git-0"
source = {
   url = "git+https://github.com/thislight/away.git",
}
description = {
   summary = "Portable asynchronous framework",
   detailed = [[This library provides a event-based coroutine scheduler.]],
   homepage = "https://github.com/thislight/away",
   license = "GPL-3"
}
dependencies = {
   "lua >=5.3, <=5.4"
}
build = {
   type = "builtin",
   modules = {
      away = "away.lua",
      ['away.debugger'] = "away/debugger/init.lua",
      ['away.debugger.mocks'] = "away/debugger/mocks.lua",
      ['away.promise'] = "away/promise.lua",
   }
}
