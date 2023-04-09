package = "away"
version = "git-0"
source = {
   url = "git+https://github.com/thislight/away.git",
}
description = {
   summary = "Portable asynchronous framework",
   detailed = [[This library provides a coroutine scheduler.]],
   homepage = "https://github.com/thislight/away",
   license = "GPL-3"
}
dependencies = {
   "lua >=5.4,<5.5"
}
build = {
   type = "builtin",
   modules = {
      away = "away.c",
      ["away.promise"] = {"away.c", "away/promise.c"},
   }
}
