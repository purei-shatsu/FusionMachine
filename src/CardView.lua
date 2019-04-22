--[[
    Documentation
--]]
local Class = require("src.Utils.Class")
local Sound = require("src.Sound")
local DisplayGroups = require("src.DisplayGroups")

local scale = 1.5
local CardView =
    Class.new(
    {
        width = 177 * scale,
        height = 254 * scale
    },
    function(self, model, position, materialList)
        self.model = model
        self.materialList = materialList
        self.displayObject = self:createDisplayObject(model:getId(), position)
    end
)

function CardView:moveToHand(position)
    local finalX = display.contentCenterX + (position - 3) * self.displayObject.width
    transition.to(
        self.displayObject,
        {
            time = 250,
            onStart = Sound.playWrapper("move"),
            transition = easing.outSine,
            delay = 150 * (position - 1),
            x = finalX
        }
    )
end

function CardView:createDisplayObject(id, position)
    local displayObject = display.newImageRect(DisplayGroups.cards, "pics/" .. id .. ".jpg", self.width, self.height)
    local finalX = display.contentCenterX + (position - 3) * displayObject.width
    displayObject.x = finalX + display.contentWidth * 1.5
    displayObject.y = display.contentCenterY

    -- --fusion material number
    local materialNumber = {}
    materialNumber.rect =
        display.newRoundedRect(
        DisplayGroups.ui,
        finalX - displayObject.width / 2 + 22,
        displayObject.y - displayObject.height / 2,
        50,
        30,
        5
    )
    materialNumber.rect.strokeWidth = 4
    materialNumber.rect:setFillColor(0.15)
    materialNumber.rect:setStrokeColor(0.63)
    materialNumber.text =
        display.newText(DisplayGroups.ui, position, materialNumber.rect.x, materialNumber.rect.y, native.systemFont, 36)
    materialNumber.text:setFillColor(0.38, 0.5, 0.97)
    materialNumber.text:setStrokeColor(0.01, 0.25, 0.49)
    self.materialNumber = materialNumber
    self:_hideMaterialNumber()

    displayObject:addEventListener("touch", self)

    return displayObject
end

function CardView:touch(event)
    if event.phase ~= "began" then
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
    --mark
    table.insert(self.materialList, self)
    self.materialNumber.text.text = #self.materialList
    self:_showMaterialNumber()
    self.displayObject.y = self.displayObject.y - 20
end

function CardView:unmarkAsMaterial(dontMove)
    --unmark
    self:_hideMaterialNumber()
    if not dontMove then
        self.displayObject.y = self.displayObject.y + 20
    end

    --remove from table
    for i = #self.materialList, 1, -1 do
        if self.materialList[i] == self then
            table.remove(self.materialList, i)
            break
        end
    end

    --update texts
    for i, m in ipairs(self.materialList) do
        m.materialNumber.text.text = i
    end
end

function CardView:getCardRotationPath(angle)
    local dx = self.width * 0.5 * (1 - math.cos(angle))
    local dy = self.height * 0.1 * (math.sin(angle))
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

function CardView:setCardRotation(angle)
    local path = self.displayObject.path
    for p, v in pairs(self:getCardRotationPath(angle)) do
        path[p] = v
    end
end

function CardView:rotateCardTo(params)
    local path = self.displayObject.path
    for p, v in pairs(self:getCardRotationPath(params.angle)) do
        params[p] = v
    end
    transition.to(path, params)
end

function CardView:getModel()
    return self.model
end

function CardView:_hideMaterialNumber()
    self.materialNumber.text.alpha = 0
    self.materialNumber.rect.alpha = 0
end

function CardView:_showMaterialNumber()
    self.materialNumber.text.alpha = 1
    self.materialNumber.rect.alpha = 1
end

return CardView
