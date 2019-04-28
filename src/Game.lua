local Class = require("Utils.Class")
local CardLocator = require("CardLocator")
local CardModel = require("CardModel")
local CardView = require("CardView")
local Sound = require("Sound")
local FusionProcessor = require("FusionProcessor")
local Animator = require("Animator")
local Database = require("Database")
local DisplayGroups = require("DisplayGroups")
local Camera = require("Camera")
local FieldSpace = require("FieldSpace")
local Eventer = require("EventSystem.Eventer")
local EndTurnButton = require("EndTurnButton")

local Game =
    Class.new(
    {
        listeners = {
            events = {
                FieldSpace = {
                    Clicked = function(self, _, _, ...)
                        self:_onFieldSpaceClicked(...)
                    end
                },
                EndTurnButton = {
                    Clicked = function(self, _, _, ...)
                        self:_onEndTurnButtonClicked(...)
                    end
                },
                MarkedAsMaterial = function(self, _, ...)
                    self:_onMaterialMarked(...)
                end,
                UnmarkedAsMaterial = function(self, _, ...)
                    self:_onMaterialUnmarked(...)
                end
            }
        }
    },
    function(self, database)
        self.locator = {}
        for side = 1, 2 do
            self.locator[side] = CardLocator:new()
            self.locator[side]:createLocation(
                "field",
                {
                    allowHoles = true
                }
            )
        end

        self.materials = {}
        self.camera = Camera:new()
        for _, displayGroup in pairs(DisplayGroups) do
            self.camera:insert(displayGroup)
        end

        self.fieldSpaces = {}
        for side = 1, 2 do
            self.fieldSpaces[side] = {}
            for position = 1, 5 do
                self.fieldSpaces[side][position] = FieldSpace:new(side, position)
            end
        end

        self.endTurnButton = EndTurnButton:new()
    end,
    Eventer
)

function Game:runPlayerTurn()
    coroutine.wrap(
        function()
            self.camera:moveToHand(1, true)
            self:_moveHandCardsBack(1)
            self:_drawCardsUntilFive(1)
        end
    )()
end

function Game:runAITurn()
    coroutine.wrap(
        function()
            self.camera:moveToHand(2, true)
            self:_moveHandCardsBack(2)
            self:_drawCardsUntilFive(2)
        end
    )()
end

function Game:_drawCardsUntilFive(side)
    --select five non-special cards for starting hand
    local amount = 5 - self.locator[side]:getLocationCount("hand")
    for cardData in Database:nrows(
        string.format(
            "select * from datas as d inner join texts as t on d.id==t.id and level<=4 order by random() limit %d",
            amount
        )
    ) do
        local position = self.locator[side]:getLocationCount("hand") + 1
        local cardModel = CardModel:new(cardData)
        local cardView = CardView:new(cardModel, side, position)
        self.locator[side]:insertCard(cardView, "hand")
        cardView:moveToHand(position)
    end
end

function Game:_fuseSelectedMaterials(position)
    Sound.play("confirm")

    --prepare Animator parameters
    local modelMaterials = {}
    local viewMaterials = {}
    for i, cardView in ipairs(self.materials) do
        viewMaterials[i] = cardView
        modelMaterials[i] = cardView:getModel()
    end
    local results = FusionProcessor.performFusion(modelMaterials)
    local side = self.materials[1]:getSide()
    local hand = self.locator[side]:getCardsInLocation("hand")

    --remove cards from locator
    for _, card in ipairs(self.materials) do
        self.locator[side]:removeCard(card)
    end

    --remove cards from materials
    for i = #self.materials, 1, -1 do
        self.materials[i]:unmarkAsMaterial(true)
    end

    --fuse
    Animator.performFusion(
        hand,
        viewMaterials,
        results,
        function(finalCard)
            self:_finishFusion(finalCard, position)
        end
    )
end

function Game:_finishFusion(finalCard, position)
    local side = finalCard:getSide()
    self.locator[side]:insertCard(finalCard, "field", position)
    finalCard:summon(position)

    self.camera:moveToField()
end

function Game:_onFieldSpaceClicked(side, position)
    if #self.materials == 0 then
        return
    end

    if side == 1 then
        --add selected card to materials
        local card = self.locator[side]:getCardsInLocation("field")[position]
        if card then
            table.insert(self.materials, 1, card)
        end

        self:_fuseSelectedMaterials(position)
    else
        --TODO
    end
end

function Game:_onEndTurnButtonClicked(side, position)
    self:runAITurn()
end

function Game:_moveHandCardsBack(side)
    for position, card in pairs(self.locator[side]:getCardsInLocation("hand")) do
        card:moveToHand(position)
    end
end

function Game:_onMaterialMarked(card)
    table.insert(self.materials, card)
    card:setMaterialNumber(#self.materials)
end

function Game:_onMaterialUnmarked(card)
    --remove from table
    for i = #self.materials, 1, -1 do
        if self.materials[i] == card then
            table.remove(self.materials, i)
            break
        end
    end

    --update texts
    for i, m in ipairs(self.materials) do
        m:setMaterialNumber(i)
    end
end

return Game
