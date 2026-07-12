local Class = require("Utils.Class")
local Sound = require("Sound")
local DisplayGroups = require("DisplayGroups")
local Transition = require("Transition")
local CardText = require("CardText")
local Event = require("OldEventSystem.Event")

local scale = 1.5
local CardView =
    Class.new(
    {
        width = 177 * scale,
        height = 254 * scale
    },
    function(self, model, side, position)
        self.model = model
        self.side = side
        self:createDisplayObject(position)
    end
)

function CardView:moveToHand(position, wait)
    local finalX = self:_getXAtPosition(position)
    local finalY = self:_getYAtPosition(self.side, position)
    self.materialNumber.displayGroup.x = finalX - self.image.width / 2 + 22
    Transition.to(
        self.displayObject,
        {
            time = 250,
            onStart = Sound.playWrapper("move"),
            transition = easing.outSine,
            delay = 150 * (position - 1),
            x = finalX,
            y = finalY
        },
        wait
    )
end

--newImageRect returns nil when the art file is missing. The card still plays, standing in as a
--white rectangle, so the gap is named in the console instead of taking the game down
function CardView:_createImage(displayObject)
    local image = display.newImageRect(displayObject, self.model:getImagePath(), self.width, self.height)
    if image then
        return image
    end

    print(string.format("missing art: %s (%s)", self.model:getName(), self.model:getImagePath()))
    image = display.newRect(displayObject, 0, 0, self.width, self.height)
    image:setFillColor(1)
    return image
end

function CardView:createDisplayObject(position)
    local displayObject = display.newGroup()
    DisplayGroups.cards:insert(displayObject)
    self.displayObject = displayObject

    local image = self:_createImage(displayObject)
    self.image = image

    local finalX = self:_getXAtPosition(position)
    local finalY = self:_getYAtPosition(self.side, position)
    displayObject.x = finalX + display.contentWidth * 1.5
    displayObject.y = finalY

    --fusion material number
    local materialNumber = {}
    materialNumber.displayGroup = display.newGroup()
    materialNumber.displayGroup.x = finalX - image.width / 2 + 22
    materialNumber.displayGroup.y = displayObject.y - image.height / 2
    DisplayGroups.ui:insert(materialNumber.displayGroup)

    materialNumber.rect = display.newRoundedRect(materialNumber.displayGroup, 0, 0, 50, 30, 5)
    materialNumber.rect.strokeWidth = 4
    materialNumber.rect:setFillColor(0.15)
    materialNumber.rect:setStrokeColor(0.63)
    materialNumber.text = display.newText(materialNumber.displayGroup, position, 0, 0, native.systemFont, 36)
    materialNumber.text:setFillColor(0.38, 0.5, 0.97)
    materialNumber.text:setStrokeColor(0.01, 0.25, 0.49)
    self.materialNumber = materialNumber
    self:_hideMaterialNumber()

    image:addEventListener("touch", self)

    self.text = CardText:new(self.model)
    displayObject:insert(self.text.displayObject)
end

function CardView:touch(event)
    if event.phase ~= "began" or not IS_PLAYER_TURN then
        return
    end

    --can't select a summoned card for fusion
    if self.summoned then
        Event.broadcast("SelectedOnField", self)
        return
    end

    --can't select AI card as material
    if self.side == 2 then
        return
    end

    Sound.play("material")
    if self.isMaterial then
        self:unmarkAsMaterial()
    else
        self:markAsMaterial()
    end
    self.isMaterial = not self.isMaterial
end

function CardView:markAsMaterial()
    Event.broadcast("MarkedAsMaterial", self)

    --mark
    self:_showMaterialNumber()
    self.displayObject.y = self.displayObject.y - 20
end

function CardView:unmarkAsMaterial(dontMove)
    Event.broadcast("UnmarkedAsMaterial", self)

    --unmark
    self:_hideMaterialNumber()
    if not dontMove then
        self.displayObject.y = self.displayObject.y + 20
    end
end

function CardView:setMaterialNumber(text)
    self.materialNumber.text.text = text
end

function CardView:_getCardDeformation(angle)
    return self.width * 0.5 * (1 - math.cos(angle)), self.height * 0.1 * math.sin(angle)
end

function CardView:getCardRotationPath(angle)
    local dx, dy = self:_getCardDeformation(angle)
    return {
        x1 = dx,
        y1 = -dy,
        x2 = dx,
        y2 = dy,
        x3 = -dx,
        y3 = -dy,
        x4 = -dx,
        y4 = dy
    }
end

--the rotation narrows the card by dx on both sides and grows its left edge by dy while shrinking
--its right one, turning it into a trapeze that reads as a 3d rotation. The corners move linearly,
--so the interior follows bilinearly: x is pulled towards the center, and y shears towards the
--shortened edge by an amount that depends on how far right the point is. The text box rides the
--card, so its corners are deformed by this same map
function CardView:getWarpPoint(angle)
    local dx, dy = self:_getCardDeformation(angle)
    return function(x, y)
        return x * (1 - 2 * dx / self.width), y * (1 - 4 * dy * x / (self.width * self.height))
    end
end

function CardView:setCardRotation(angle)
    local path = self.image.path
    for p, v in pairs(self:getCardRotationPath(angle)) do
        path[p] = v
    end
    self.text:setWarp(self:getWarpPoint(angle))
end

function CardView:rotateCardTo(params)
    local path = self.image.path
    for p, v in pairs(self:getCardRotationPath(params.angle)) do
        params[p] = v
    end
    transition.to(path, params)

    self.text:warpTo(self:getWarpPoint(params.angle), params)
end

function CardView:getModel()
    return self.model
end

function CardView:summon(position)
    self.summoned = true
    Transition.to(
        self.displayObject,
        {
            time = 400,
            transition = easing.inOutSine,
            x = self:_getXAtPosition(position),
            y = self.side == 1 and self.image.height / 2 or -self.image.height / 2
        },
        true
    )
    self.displayObject:toBack()
end

function CardView:getSide()
    return self.side
end

function CardView:_hideMaterialNumber()
    self.materialNumber.text.alpha = 0
    self.materialNumber.rect.alpha = 0
end

function CardView:_showMaterialNumber()
    self.materialNumber.text.alpha = 1
    self.materialNumber.rect.alpha = 1
end

function CardView:_getXAtPosition(position)
    return display.contentCenterX + (position - 3) * self.image.width
end

function CardView:_getYAtPosition(position)
    return display.contentHeight - (self.side == 1 and 0.5 or 3.5) * self.image.height
end

return CardView
