
local record Promise<T>
    fulfilled: boolean
    value: nil | T
    error: nil | any
    wakeback_threads: {thread}

    resolve: function(self: Promise<T>, val: T): nil
    reject: function(self: Promise<T>, err: any): nil
    expose: function(self: Promise<T>): T
    wait: function(self: Promise<T>): T
    just_wait: function(self: Promise<T>): nil
    on_value: function<R>(self: Promise<T>, fn: (function(T): R)): Promise<R>
    on_err: function<R>(self: Promise<T>, fn: (function(any): (R | nil))): Promise<R>
end

local record away_promise
    create: function<T>(execfn: (function(resolve: (function(T): nil), reject: (function(any): nil), Promise))): Promise
    all: function<T>(t: {Promise<T>}): Promise<{T}>
    race: function<T>(t: {Promise<T>}): Promise<T>
    resolve: function<T>(self: Promise<T>, val: T): nil
    reject: function<T>(self: Promise<T>, err: any): nil
    expose: function<T>(self: Promise<T>): T
    wait: function<T>(self: Promise<T>): T
    just_wait: function<T>(self: Promise<T>): nil
    on_value: function<T,R>(self: Promise<T>, fn: (function(T): R)): Promise<R>
    on_err: function<T,R>(self: Promise<T>, fn: (function(any): (R | nil))): Promise<R>
end

return away_promise
