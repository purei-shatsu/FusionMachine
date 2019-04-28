local Class = require("Utils.Class")
local Transition = require("Transition")

local Camera =
    Class.new(
    {
        duration = 400
    },
    function(self)
        self.displayGroup = display.newGroup()
    end
)

function Camera:insert(displayObject)
    self.displayGroup:insert(displayObject)
end

function Camera:moveToField(wait)
    self:_moveTo(display.contentHeight / 2, wait)
end

function Camera:moveToHand1(wait)
    self:_moveTo(0, wait)
end

function Camera:moveToHand2(wait)
    self:_moveTo(display.contentHeight, wait)
end

function Camera:_moveTo(y, wait)
    Transition.to(
        self.displayGroup,
        {
            duration = self.duration,
            y = y,
            transition = easing.inOutSine
        },
        wait
    )
end

return Camera
