local a = require "away"
local d = require "away.debugger"

describe("away.series", function()
    local Series = require "away.series"

    describe("series", function()
        it("will raise error if listen twice on one series",
           d:wrapenv(function(schd, debugger)
            debugger:set_timeout(schd, 10)
            schd:run_task(function()
                local series = Series.create()
                series:listen(function() end)
                assert.has_error(function()
                    series:listen(function() end)
                end)
            end)
            schd:run()
        end))

        it("is able to ship values in order", d:wrapenv(
               function(schd, debugger)
                debugger:set_timeout(schd, 10)
                local series = Series.create()

                schd:run_task(function()
                    local i = 0
                    series:listen(function(v)
                        assert.equals(i, v)
                        i = i + 1
                    end)
                end)

                schd:run_task(function()
                    for i = 0, 10 do series:put(i) end
                end)

                schd:run()
            end))
    end)

    describe("broadcast series", function()
        it("is able to ship values in order", d:wrapenv(
               function(schd, debugger)
                debugger:set_timeout(schd, 10)
                local series = Series.create_broadcast()

                schd:run_task(function()
                    local i = 0
                    series:listen(function(v)
                        assert.equals(i, v)
                        i = i + 1
                    end)
                end)

                schd:run_task(function()
                    local i = 0
                    series:listen(function(v)
                        assert.equals(i, v)
                        i = i + 1
                    end)
                end)

                schd:run_task(function()
                    for i = 0, 10 do series:put(i) end
                end)

                schd:run()
            end))
    end)
end)
