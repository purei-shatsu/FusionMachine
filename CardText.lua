local Class = require("Utils.Class")

--paints the card's stats over the ones printed on the art. It is a snapshot rather than a group so
--that it has a path of its own: the card fakes its 3d rotation by pulling the four corners of the
--art into a trapeze, and only a shape can be deformed the same way
local CardText =
    Class.new(
    {},
    function(self, model)
        self.width, self.height = model:getTextSize()

        local snapshot = display.newSnapshot(self.width, self.height)
        self.displayObject = snapshot
        self.baseX, self.baseY = model:getTextPosition()
        snapshot.x, snapshot.y = self.baseX, self.baseY

        display.newRect(snapshot.group, 0, 0, self.width, self.height)

        local text =
            display.newText(
            {
                parent = snapshot.group,
                text = model:getDisplayText(),
                width = self.width,
                fontSize = 27,
                align = "center"
            }
        )
        text:setFillColor(0, 0, 0)
        snapshot:invalidate()
    end
)

--offsets each corner of the text box by where the card's deformation sends it. The offsets are the
--path's own coordinates, relative to the corners of the undeformed box, so the snapshot itself
--stays at its position on the card and only its quad moves
function CardText:_getWarpPath(warpPoint)
    local halfWidth = self.width / 2
    local halfHeight = self.height / 2
    --a rect path numbers its corners upper left, lower left, lower right, upper right
    local corners = {
        {-halfWidth, -halfHeight},
        {-halfWidth, halfHeight},
        {halfWidth, halfHeight},
        {halfWidth, -halfHeight}
    }

    local path = {}
    for i, corner in ipairs(corners) do
        local x = self.baseX + corner[1]
        local y = self.baseY + corner[2]
        local warpedX, warpedY = warpPoint(x, y)
        path["x" .. i] = warpedX - x
        path["y" .. i] = warpedY - y
    end
    return path
end

function CardText:setWarp(warpPoint)
    local path = self.displayObject.path
    for property, value in pairs(self:_getWarpPath(warpPoint)) do
        path[property] = value
    end
end

--every offset is affine in the corner displacements the card's own path transitions, so running
--this with the art's timing keeps text and art locked together frame by frame
function CardText:warpTo(warpPoint, params)
    local path = self:_getWarpPath(warpPoint)
    path.time = params.time
    path.delay = params.delay
    path.transition = params.transition
    transition.to(self.displayObject.path, path)
end

return CardText
