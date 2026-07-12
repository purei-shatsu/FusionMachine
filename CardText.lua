local Class = require("Utils.Class")

--paints the card's stats over the ones printed on the art
local CardText =
    Class.new(
    {},
    function(self, model)
        self.displayObject = display.newGroup()
        self.baseX, self.baseY = model:getTextPosition()
        self.displayObject.x, self.displayObject.y = self.baseX, self.baseY

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

--the card is squashed and stretched by deforming the art's quad, which a display group can't
--inherit, so the text box reproduces the deformation with its own scale. The quad displaces its
--corners linearly, so a point at (baseX, baseY) from the card's center lands scaled by the same factors
function CardText:_getWarp(xScale, yScale)
    return {
        xScale = xScale,
        yScale = yScale,
        x = self.baseX * xScale,
        y = self.baseY * yScale
    }
end

function CardText:setWarp(xScale, yScale)
    for property, value in pairs(self:_getWarp(xScale, yScale)) do
        self.displayObject[property] = value
    end
end

--the scales are affine in the quad's corner displacements, so transitioning them with the same
--timing as the art keeps text and art locked together frame by frame
function CardText:warpTo(xScale, yScale, params)
    local warp = self:_getWarp(xScale, yScale)
    warp.time = params.time
    warp.delay = params.delay
    warp.transition = params.transition
    transition.to(self.displayObject, warp)
end

return CardText
