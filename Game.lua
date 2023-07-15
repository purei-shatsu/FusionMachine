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
local Eventer = require("OldEventSystem.Eventer")
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

Game.forbiddenMemoriesIds =
    "89631139, 15025844, 76184692, 88819587, 15303296, 41392891, 87796900, 14181608, 40575313, 87564352, 13069066, 40453765, 72842870, 18246479, 45231177, 71625222, 8124921, 44519536, 70903634, 7902349, 33396948, 70781052, 6285791, 32274490, 69669405, 5053103, 32452818, 68846917, 4931562, 31339260, 67724379, 94119974, 30113682, 66602787, 46986414, 29491031, 66889139, 6368038, 28279543, 55763552, 91152256, 28546905, 54541900, 91939608, 27324313, 53829412, 80813021, 26202165, 53606874, 89091579, 15480588, 52584282, 88979991, 15367030, 41762634, 87756343, 14141448, 40640057, 40374923, 13429800, 49417509, 76812113, 12206212, 49791927, 90357090, 1184620, 48579379, 14977074, 41462083, 77456781, 14851496, 40240595, 76634149, 13039848, 49127943, 76512652, 2906250, 48305365, 75390004, 1784619, 38289717, 74677422, 62121, 33066139, 69455834, 6840573, 32344688, 68339286, 95727991, 31122090, 68516705, 94905343, 30090452, 67494157, 93889755, 20277860, 66672569, 92667214, 29155212, 55550921, 92944626, 28933734, 55337339, 22026707, 46457856, 54615781, 80600490, 27094595, 53493204, 89987208, 16972957, 52367652, 9159938, 15150365, 41544074, 88643173, 14037717, 41422426, 77827521, 13215230, 40200834, 76704943, 13193642, 49587396, 75582395, 2971090, 48365709, 75850803, 90963488, 37243151, 74637266, 32864, 37421579, 63515678, 52800428, 36304921, 62793020, 9197735, 35282433, 62671448, 98075147, 34460851, 61454890, 97843505, 24348204, 732302, 36121917, 63125616, 99510761, 36904469, 62403074, 98898173, 25882881, 53581214, 94675535, 20060230, 53293545, 93553943, 29948642, 56342351, 92731455, 28725004, 55210709, 81618817, 28003512, 54098121, 81492226, 17881964, 53375573, 80770678, 16768387, 53153481, 89558090, 15042735, 42431843, 88435542, 15820147, 41218256, 77603950, 14708569, 40196604, 77581312, 3985011, 49370026, 64511793, 2863439, 49258578, 75646173, 1641882, 38035986, 9430387, 1929294, 37313348, 63308047, 756652, 36151751, 63545455, 99030164, 36039163, 75356564, 98818516, 75889523, 61201220, 98795934, 24194033, 60589682, 97973387, 38142739, 39175982, 96851799, 15510988, 53832650, 85639257, 15401633, 58528964, 84916669, 11901678, 57305373, 84794011, 10189126, 56283725, 83678433, 19066538, 46461247, 22855882, 54844990, 46718686, 17733394, 8783685, 80516007, 17511156, 43905751, 89494469, 16899564, 42883273, 89272878, 84285623, 41061625, 78556320, 8944575, 41949033, 47695416, 3732747, 40826495, 76211194, 3606209, 39004808, 75499502, 2483611, 38982356, 75376965, 1761063, 37160778, 64154377, 549481, 37043180, 63432835, 99426834, 36821538, 62210247, 15150371, 25109950, 62193699, 98582704, 18710707, 51371017, 97360116, 15507080, 50259460, 96643568, 23032273, 59036972, 86421986, 22910685, 58314394, 85309439, 11793047, 58192742, 84686841, 10071456, 47060154, 83464209, 10859908, 46247516, 82742611, 19737320, 45121025, 72520073, 18914778, 45909477, 71407486, 7892180, 44287299, 70681994, 7670542, 33064647, 75559356, 2957055, 38942059, 85705804, 61854111, 37120512, 4614116, 40619825, 77007920, 3492538, 39897277, 46009906, 2370081, 39774685, 65169794, 1557499, 38552107, 64047146, 1435851, 37820550, 63224564, 90219263, 36607978, 63102017, 99597615, 15052462, 91595718, 98374133, 25769732, 51267887, 98252586, 77027445, 50045299, 87430998, 23424603, 50913601, 86318356, 22702055, 59197169, 53129443, 12580477, 58074572, 38199696, 11868825, 47852924, 84257639, 76103675, 46130346, 73134081, 19523799, 46918794, 72302403, 18807108, 45895206, 71280811, 12829151, 44073668, 71068263, 7562372, 33951077, 70345785, 6740720, 33734439, 69123138, 5628232, 32012841, 68401546, 5405694, 31890399, 67284908, 94773007, 30778711, 63162310, 99551425, 25955164, 62340868, 98434877, 25833572, 51228280, 97612389, 24611934, 50005633, 97590747, 23995346, 59383041, 26378150, 62762898, 99261403, 25655502, 52040216, 98049915, 24433920, 51828629, 87322377, 24311372, 50705071, 86100785, 13599884, 59983499, 86088138, 12472242, 58861941, 85255550, 11250655, 48649353, 84133008, 10538007, 47922711, 73911410, 10315429, 46700124, 72299832, 9293977, 45688586, 72076281, 8471389, 44865098, 71950093, 7359741, 34743446, 70138455, 7526150, 33621868, 69015963, 6400512, 32809211, 69893315, 95288024, 31786629, 68171737, 94566432, 31560081, 67959180, 93343894, 20848593, 66836598, 93221206, 29616941, 55014050, 92409659, 28593363, 55998462, 81386177, 23771716, 50176820, 86164529, 23659124, 59053232, 85448931, 12436646, 58831685, 85326399, 11714098, 48109103, 84103702, 10598400, 47986555, 73481154, 10476868, 46864967, 72269672, 9653271, 45042329, 12146024, 48531733, 84926738, 11324436, 47319141, 74703140, 10202894, 46696593, 73081602, 9076207, 46474915, 72869010, 8353769, 35752363, 71746462, 8131171, 34536276, 70924884, 7019529, 33413638, 60802233, 6297941, 33691040, 69780745, 95174353, 32569498, 68963107, 95952802, 21347810, 67841515, 94230224, 20624263, 67629977, 93013676, 29402771, 56907389, 92391084, 29380133, 55784832, 81179446, 28563545, 54652250, 81057959, 17441953, 53830602, 80234301, 16229315, 53713014, 89112729, 16507828, 42591472, 84990171, 11384280, 47879985, 74277583, 10262698, 46657337, 73051941, 9540040, 46534755, 72929454, 8327462, 35712107, 71107816, 8201910, 34690519, 70084224, 7489323, 33878931, 60862676, 6367785, 32751480, 69140098, 95144193, 32539892, 68928540, 94412545, 21817254, 7805359, 34290067, 60694662, 7089711, 33178416, 69572024, 96967123, 32355828, 69750536, 95744531, 21239280, 68638985, 94022093, 21417692, 57405307, 93900406, 20394040, 56789759, 93788854, 29172562, 55567161, 82065276, 28450915, 55444629, 81843628, 17238333, 54622031, 80727036, 17115745, 43500484, 89904598, 16353197, 42348802, 89832901, 15237615, 42625254, 78010363, 14015067, 41403766, 77998771, 4392470, 40387124, 76775123, 3170832, 35565537, 72053645, 8058240, 34442949, 61831093, 7225792, 34320307, 60715406, 6103114, 33508719, 69992868, 96981563, 32485271, 68870276, 95265975, 21263083, 68658728, 94042337, 20541432, 57935140, 93920745, 20315854, 56713552, 93108297, 29692206, 55691901, 82085619, 28470714, 55875323, 81863068, 17358176, 54752875, 80141480, 17535588, 43530283, 29929832, 56413937, 82818645, 29802344, 55291359, 81686058, 18180762, 54579801, 81563416, 17968114, 43352213, 80741828, 16246527, 43230671, 79629370, 15023985, 42418084, 78402798, 5901497, 41396436, 78780140, 4179849, 40173854, 77568553, 3056267, 30451366, 76446915, 2830619, 39239728, 65623423, 2118022, 38116136, 64501875, 91996584, 37390589, 64389297, 90873992, 32268901, 69666645, 95051344, 22046459, 68540058, 94939166, 21323861, 57728570, 94716515, 20101223, 56606928, 83094937, 29089635, 56483330, 82878489, 29267084, 55761792, 81756897, 18144506, 54539105, 81933259, 17928958, 43417563, 80811661, 16206366, 43694075, 79699070, 15083728, 42578427, 78977532, 15361130, 41356845, 77754944, 4149689, 40633297, 77622396, 3027001, 39411600, 76806714, 2304453, 39399168, 5783166, 41182875, 78577570, 4561679, 31066283, 77454922, 4849037, 30243636, 76232340, 3627449, 39111158, 66516792, 2504891, 38999506, 65393205, 91782219, 38277918, 64271667, 90660762, 27054370, 63459075, 90844184, 26932788, 62337487, 99721536, 25110231, 76792184, 30208479"

function Game:_drawCardsUntilFive(side)
    --select five non-special cards for starting hand
    local amount = 5 - self.locator[side]:getLocationCount("hand")
    for cardData in Database:nrows(
        string.format(
            "select * from datas as d inner join texts as t on d.id==t.id and level<=4 and d.id in (%s) order by random() limit %d",
            Game.forbiddenMemoriesIds,
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
                if self:_isFusionBetter(resultWithField, materialsWithField, true, bestResult, bestMaterials, bestReplace) then
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
