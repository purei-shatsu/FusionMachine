local Class = require("Utils.Class")

--paints the card's stats over the ones printed on the art
local CardText =
    Class.new(
    {},
    function(self, model)
        self.displayObject = display.newGroup()
        self.displayObject.x, self.displayObject.y = model:getTextPosition()

        self.width, self.height = model:getTextSize()

        display.newRect(self.displayObject, 0, 0, self.width, self.height)

        local text =
            display.newText(
            {
                parent = self.displayObject,
                text = model:getDisplayText(),
                width = self.width,
                fontSize = 27,
                align = "center"
            }
        )
        text:setFillColor(0, 0, 0)
    end
)

function CardText:hide()
    self.displayObject.isVisible = false
end

function CardText:show()
    self.displayObject.isVisible = true
end

return CardText
