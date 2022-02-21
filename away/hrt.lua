
local timers = {}

if pcall(require, "chronos") then
    -- https://luarocks.org/modules/ldrumm/chronos
    local chronos = require "chronos"
    local nanotime = chronos.nanotime
    if nanotime then
        function timers.chronos()
            return nanotime() * 1000
        end
    end
end

if pcall(require "luaposix") then
    -- https://luaposix.github.io/luaposix/modules/posix.time.html#clock_gettime
    local posix = require "luaposix"
    local clock_gettime = posix.time.clock_gettime
    local CLOCK_MONOTONIC = posix.time.CLOCK_MONOTONIC
    
    if clock_gettime and CLOCK_MONOTONIC then
        function timers.luaposix()
            local timespec = clock_gettime(CLOCK_MONOTONIC)
            return timespec.tv_sec * 1000 + timespec.tv_nsec
        end
    end
end

if ngx then
    -- https://github.com/openresty/lua-nginx-module#ngxnow
    local now = ngx.now
    if now then
        function timers.nginx()
            return now() * 1000
        end
    end
end

if os then
    local time = os.time
    if time then
        function timers.os()
            return time() * 1000
        end
    end
end

local PICK_LIST = {
    "nginx",
    "chronos",
    "luaposix",
    "os"
}

-- Get the best high resulotion timer and the name.
-- Return nil if no timer provided.
local function get()
    for i, v in ipairs(PICK_LIST) do
        if timers[v] then
            return timers[v], v
        end
    end
    return nil, nil
end

local mod = {
    timers = timers,
    get = get,
}

return mod
