local Class = require("Utils.Class")
local DisplayGroups = require("DisplayGroups")
local CardView = require("CardView")
local Event = require("OldEventSystem.Event")

local FieldSpace =
    Class.new(
    {},
    function(self, side, position)
        self.rect = display.newRect(DisplayGroups.ui, (position - 1) * CardView.width, (1.5 - side) * CardView.height, CardView.width, CardView.height)
        self.rect:addEventListener("touch", self)
        self.rect.isVisible = false
        self.rect.isHitTestable = true

        self.side = side
        self.position = position
    end
)

function FieldSpace:touch(event)
    if event.phase ~= "began" then
        return
    end

    Event.broadcast("FieldSpace", "Clicked", self.side, self.position)
end

return FieldSpace
