local Class = require("Utils.Class")
local Event = require("EventSystem.Event")

local EndTurnButton =
    Class.new(
    {
        size = 100
    },
    function(self)
        self.rect = display.newRect(1122, display.contentHeight / 2 - self.size / 2, self.size, self.size)
        self.rect:addEventListener("touch", self)
    end
)

function EndTurnButton:touch(event)
    if event.phase ~= "began" then
        return
    end
    Event.broadcast("EndTurnButton", "Clicked")
end

return EndTurnButton
