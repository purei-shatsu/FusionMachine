local Class = require("Utils.Class")

--paints the card's stats over the ones printed on the art
local CardText =
    Class.new(
    {
        width = 225,
        height = 72
    },
    function(self, model)
        self.displayObject = display.newGroup()
        self.displayObject.x = 0
        self.displayObject.y = 132

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
