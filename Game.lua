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
                end,
                SelectedOnField = function(self, _, ...)
                    self:_onSelectedOnField(...)
                end
            }
        },
        aiDifficulty = 2
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
        for _, displayGroup in pairs(DisplayGroups) do
            Camera.insert(displayGroup)
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
            self.attacker = nil
            IS_PLAYER_TURN = true
            Camera.moveToHand(1, true)
            self:_moveHandCardsBack(1)
            self:_drawCardsUntilFive(1)
        end
    )()
end

function Game:runAITurn()
    coroutine.wrap(
        function()
            IS_PLAYER_TURN = false
            Camera.moveToHand(2, true)
            self:_moveHandCardsBack(2)
            self:_drawCardsUntilFive(2)
            self:_playAIFusion()
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
        cardView:moveToHand(position, position == 5)
    end
end

function Game:_fuseSelectedMaterials(position)
    Sound.play("confirm")

    --add card in location to materials
    local side = self.materials[1]:getSide()
    local card = self.locator[side]:getCardsInLocation("field")[position]
    if card then
        table.insert(self.materials, 1, card)
    end

    --prepare Animator parameters
    local viewMaterials = {}
    for i, cardView in ipairs(self.materials) do
        viewMaterials[i] = cardView
    end
    local results = FusionProcessor.performFusion(self.materials)
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

    Camera.moveToField(true)

    if not IS_PLAYER_TURN then
        self:_makeAIAttacks()
    end
end

function Game:_onFieldSpaceClicked(side, position)
    if #self.materials == 0 then
        return
    end

    if side == 1 then
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

function Game:_isFusionBetter(resultA, materialsA, replacesA, resultB, materialsB, replacesB)
    --if either are nil, return the other
    if resultB == nil then
        return true
    end
    if resultA == nil then
        return false
    end

    local atkA = resultA:getAttack()
    local atkB = resultB:getAttack()
    local defA = resultA:getDefense()
    local defB = resultB:getDefense()
    local amountA = #materialsA
    local amountB = #materialsB

    --more attack wins
    if atkA > atkB then
        return true
    end
    if atkA < atkB then
        return false
    end

    --more defense wins
    if defA > defB then
        return true
    end
    if defA < defB then
        return false
    end

    --not replacing wins
    if not replacesA and replacesB then
        return true
    end
    if replacesA and not replacesB then
        return false
    end

    --more materials wins
    if amountA > amountB then
        return true
    end
    if amountA < amountB then
        return false
    end

    --if tied everything, A wins
    return true
end

function Game:_playAIFusion()
    --choose AI dificulty based on card difference (but never go easier)
    local AICards = self.locator[2]:getLocationCount("field")
    local playerCards = self.locator[1]:getLocationCount("field")
    self.aiDifficulty = math.max(2, playerCards - AICards + 1, self.aiDifficulty)

    --choose best fusion
    local hand = self.locator[2]:getCardsInLocation("hand")
    local field = self.locator[2]:getCardsInLocation("field")
    local emptyPosition
    for position = 1, 5 do
        if not field[position] then
            emptyPosition = position
            break
        end
    end
    local bestResult, bestMaterials, bestPosition, bestReplace
    for materials in permutations(hand, 1, self.aiDifficulty) do
        --check result if playing on an empty position
        if emptyPosition then
            local results = FusionProcessor.performFusion(materials)
            local result = results[#results] or materials[1]:getModel()
            if self:_isFusionBetter(result, materials, false, bestResult, bestMaterials, bestReplace) then
                bestResult = result
                bestMaterials = materials
                bestPosition = emptyPosition
                bestReplace = false
            end
        end

        --check results if playing over cards on the field
        if #materials + 1 <= self.aiDifficulty or not emptyPosition then --can't go over fusion limit, unless there is not empty position
            for position, card in pairs(field) do
                --add card to materials
                local materialsWithField = {card}
                for i, m in ipairs(materials) do
                    materialsWithField[i + 1] = m
                end

                --check result
                local resultsWithField = FusionProcessor.performFusion(materialsWithField)
                local resultWithField = resultsWithField[#resultsWithField]
                if
                    self:_isFusionBetter(
                        resultWithField,
                        materialsWithField,
                        true,
                        bestResult,
                        bestMaterials,
                        bestReplace
                    )
                 then
                    bestResult = resultWithField
                    bestMaterials = materialsWithField
                    bestPosition = position
                    bestReplace = true
                end
            end
        end
    end

    --remove card on field from materials and table
    if bestReplace then
        table.remove(bestMaterials, 1)
    end

    --selected cards as materials
    for _, card in ipairs(bestMaterials) do
        card:markAsMaterial()
    end

    --fuse
    self:_fuseSelectedMaterials(bestPosition)
end

local function weakAtkOrder(a, b)
    return a:getModel():getAttack() < b:getModel():getAttack()
end

local function strongAtkOrder(a, b)
    return a:getModel():getAttack() > b:getModel():getAttack()
end

function Game:_makeAIAttacks()
    local hasMoreCards = self.locator[2]:getLocationCount("field") > self.locator[1]:getLocationCount("field")

    --get AI cards on field
    local attackersDict = self.locator[2]:getCardsInLocation("field")
    local attackers = {}
    for _, attacker in pairs(attackersDict) do
        attackers[#attackers + 1] = attacker
    end

    --order by atk (weaker first)
    table.sort(attackers, weakAtkOrder)

    --for each attacker, attack the strongest card that is weaker than it
    for _, attacker in ipairs(attackers) do
        local attackerAtk = attacker:getModel():getAttack()

        --get targets
        local targetsDict = self.locator[1]:getCardsInLocation("field")
        local targets = {}
        for _, target in pairs(targetsDict) do
            targets[#targets + 1] = target
        end

        --order by atk (stronger first)
        table.sort(targets, strongAtkOrder)

        --attack first with atk lower (or same atk if has more cards)
        for _, target in ipairs(targets) do
            local targetAtk = target:getModel():getAttack()
            if attackerAtk > targetAtk or (hasMoreCards and attackerAtk == targetAtk) then
                self:_attack(attacker, target)
                break
            end
        end
    end

    --finish turn
    self:runPlayerTurn()
end

function Game:_onSelectedOnField(card)
    if card:getSide() == 1 then
        --card belongs to player, set it as the attacker
        Sound.play("confirm")
        self.attacker = card
    elseif self.attacker then
        --card belongs to AI, finish attack if already selected an attacker
        Sound.play("confirm")
        local target = card
        coroutine.wrap(
            function()
                self:_attack(self.attacker, target)
                self.attacker = nil
            end
        )()
    end
end

function Game:_attack(cardA, cardB)
    Animator.performAttack(cardA, cardB)

    --determine which cards were defeated
    local modelA = cardA:getModel()
    local modelB = cardB:getModel()
    local defeated = {}
    local atkA = modelA:getAttack()
    local atkB = modelB:getAttack()
    if atkA <= atkB then
        defeated[#defeated + 1] = cardA
    end
    if atkB <= atkA then
        defeated[#defeated + 1] = cardB
    end

    --destroy defeated cards
    for _, card in ipairs(defeated) do
        --remove from locator
        local side = card:getSide()
        self.locator[side]:removeCard(card)

        --destroy display object
        card.displayObject:removeSelf()
    end
end

return Game
