local MemoryCleaner = {
    callbacks = {}
}

function MemoryCleaner.register(callback)
    table.insert(MemoryCleaner.callbacks, callback)
end

--clear memory
local function onSystemEvent(event)
    if event.type == "applicationExit" then
        for _, callback in ipairs(MemoryCleaner.callbacks) do
            callback()
        end
        collectgarbage()
    end
end
Runtime:addEventListener("system", onSystemEvent)

return MemoryCleaner
