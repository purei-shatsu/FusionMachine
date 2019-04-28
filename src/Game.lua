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
        self.locator = CardLocator:new()
        self.locator:createLocation(
            "field",
            {
                allowHoles = true
            }
        )

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

function Game:runTurn()
    coroutine.wrap(
        function()
            self.camera:moveToHand1()
            self:_moveHandCardsBack()
            self:drawCardsUntilFive()
        end
    )()
end

function Game:drawCardsUntilFive()
    --select five non-special cards for starting hand
    local amount = 5 - self.locator:getLocationCount("hand")
    for cardData in Database:nrows(
        string.format(
            "select * from datas as d inner join texts as t on d.id==t.id and level<=4 order by random() limit %d",
            amount
        )
    ) do
        local position = self.locator:getLocationCount("hand") + 1
        local cardModel = CardModel:new(cardData)
        local cardView = CardView:new(cardModel, position)
        self.locator:insertCard(cardView, "hand")
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
    local hand = self.locator:getCardsInLocation("hand")

    --remove cards from locator
    for _, card in ipairs(self.materials) do
        self.locator:removeCard(card)
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
    self.locator:insertCard(finalCard, "field", position)
    finalCard:summon(position)

    self.camera:moveToField()
end

function Game:_onFieldSpaceClicked(side, position)
    if #self.materials == 0 then
        return
    end

    --add selected card to materials
    local card = self.locator:getCardsInLocation("field")[position]
    if card then
        table.insert(self.materials, 1, card)
    end

    self:_fuseSelectedMaterials(position)
end

function Game:_onEndTurnButtonClicked(side, position)
    self:runTurn()
end

function Game:_moveHandCardsBack()
    for position, card in pairs(self.locator:getCardsInLocation("hand")) do
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
