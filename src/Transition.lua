local Transition = {}

function Transition.to(object, params, wait)
    local co = coroutine.running()
    if wait and not co then
        error("Transition can only wait inside a coroutine.", 2)
    end

    if wait then
        local oldOnComplete = params.onComplete
        params.onComplete = function(...)
            if oldOnComplete then
                oldOnComplete(...)
            end
            coroutine.resume(co)
        end
    end

    transition.to(object, params)
    if wait then
        coroutine.yield()
    end
end

return Transition
