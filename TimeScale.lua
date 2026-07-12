--Solar2D has no equivalent to Unity's Time.timeScale: the transition and timer libraries read the
--real clock internally and only expose pause/resume. So slow motion is done by dividing every
--duration and delay at the moment it is requested, which means patching the two globals every
--animation in the game ultimately goes through.
local TimeScale = {}

local slowScale = 0.1
local defaultTransitionTime = 500 --Solar2D's default when params.time is omitted

local scale = 1

local rawTransitionTo = transition.to
local rawPerformWithDelay = timer.performWithDelay

--a scale of 0.1 makes everything take ten times longer
function TimeScale.apply(duration)
    return duration / scale
end

transition.to = function(object, params)
    if scale == 1 then
        return rawTransitionTo(object, params)
    end

    --params is copied rather than scaled in place, because CardView:rotateCardTo passes the same
    --table here and then to CardText:warpTo, which reads params.time back out to keep the text
    --locked to the art -- scaling in place would scale the text a second time
    local scaled = {}
    for key, value in pairs(params) do
        scaled[key] = value
    end
    scaled.time = TimeScale.apply(params.time or defaultTransitionTime)
    if params.delay then
        scaled.delay = TimeScale.apply(params.delay)
    end

    return rawTransitionTo(object, scaled)
end

timer.performWithDelay = function(delay, listener, iterations)
    return rawPerformWithDelay(TimeScale.apply(delay), listener, iterations)
end

Runtime:addEventListener(
    "key",
    function(event)
        if event.keyName == "leftControl" then
            if event.phase == "down" then
                scale = slowScale
            elseif event.phase == "up" then
                scale = 1
            end
        end
        return false
    end
)

return TimeScale
