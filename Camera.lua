local Class = require("Utils.Class")
local Transition = require("Transition")

local duration = 400
local displayGroup = display.newGroup()

local Camera = {}

function Camera.insert(displayObject)
    displayGroup:insert(displayObject)
end

function Camera.moveToField(wait)
    Camera._moveTo(display.contentHeight / 2, wait)
end

function Camera.moveToHand(side, wait)
    Camera._moveTo(side == 1 and 0 or display.contentHeight, wait)
end

function Camera.getY()
    return -displayGroup.y
end

function Camera._moveTo(y, wait)
    Transition.to(
        displayGroup,
        {
            duration = duration,
            y = y,
            transition = easing.inOutSine
        },
        wait
    )
end

return Camera
