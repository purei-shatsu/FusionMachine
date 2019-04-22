local Class = require("src.Utils.Class")
local CardLocator = require("src.CardLocator")
local CardModel = require("src.CardModel")
local CardView = require("src.CardView")
local Sound = require("src.Sound")
local FusionProcessor = require("src.FusionProcessor")
local Animator = require("src.Animator")
local Database = require("src.Database")

local Game =
    Class.new(
    {},
    function(self, database)
        self.locator = CardLocator:new()
        self.materials = {}

        --keyboard
        Runtime:addEventListener(
            "key",
            function(event)
                if event.keyName == "space" and event.phase == "down" then
                    self:fuseSelectedMaterials()
                end
            end
        )
    end
)

function Game:drawStartingHand()
    --select five non-special cards for starting hand
    local position = 1
    for cardData in Database:nrows(
        "select * from datas as d inner join texts as t on d.id==t.id and atk<=2000 and def<=2000 order by random() limit 5"
        --TODO level<=4
    ) do
        local cardModel = CardModel:new(cardData)
        --TODO instead of passing self.materials, create a listener and update it in this class
        local cardView = CardView:new(cardModel, position, self.materials)
        self.locator:insertCard(cardView, "hand")
        cardView:moveToHand(position)
        position = position + 1

        --TODO DELETA ISSO
        cardView:markAsMaterial()
    end
end

function Game:fuseSelectedMaterials()
    if #self.materials < 2 then
        return
    end

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

    --remove cards from materials
    for i = #self.materials, 1, -1 do
        self.materials[i]:unmarkAsMaterial(true)
    end

    --fuse
    Animator.performFusion(hand, viewMaterials, results)
end

return Game
