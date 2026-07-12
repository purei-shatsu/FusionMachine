local Database = require("Database")
local DigimonCardModel = require("DigimonCardModel")
local DigimonTraits = require("DigimonTraits")

local DigimonRules = {}

local database = Database.open("digimon.cdb")

--only Digimon cards. Cards with no art are played anyway, so a missing image fails loudly
local drawLevel = 3

--the card pool the game plays with, e.g. {"BT24", "EX11"}. Empty means every set.
--restricts both the drawn hands and the fusion results
local drawSets = {"BT23"}

local function toSqlList(colors)
    return table.concat(colors, ",")
end

local function drawSetsClause()
    if #drawSets == 0 then
        return ""
    end
    local quoted = {}
    for _, setCode in ipairs(drawSets) do
        table.insert(quoted, string.format("'%s'", setCode))
    end
    return string.format(" and c.set_code in (%s)", table.concat(quoted, ","))
end

--colors live in a child table, so pull them back with the row as "0,5". The trait is the
--first of the card's types, and the only one that counts
local selectCard =
    [[
    select c.*, (select group_concat(color) from card_colors x where x.card_id==c.card_id) as colors,
                (select t.type_en from card_types t where t.card_id==c.card_id and t.ord==0) as trait
    from cards as c inner join sets as s on s.set_code==c.set_code
    where c.card_kind==0
    ]] ..
    drawSetsClause()

local function union(colorsA, colorsB)
    local seen = {}
    local result = {}
    for _, colors in ipairs({colorsA, colorsB}) do
        for _, color in ipairs(colors) do
            if not seen[color] then
                seen[color] = true
                table.insert(result, color)
            end
        end
    end
    return result
end

function DigimonRules.drawCards(amount)
    local cards = {}
    local sqlQuery = string.format("%s and c.level==%d order by random() limit %d", selectCard, drawLevel, amount)
    for data in database:nrows(sqlQuery) do
        table.insert(cards, DigimonCardModel:new(data))
    end
    return cards
end

--[[
    Fusion Conditions:
        Level is one above the highest material;
        Every colour of the result comes from one of the materials;
        The result shares at least one colour with each material;
        The result has the trait of one of the materials.
    Order by: colour count, newest set, id

    All four conditions are symmetric in a and b, so the fusion is commutative, and
    the ordering is total, so it is deterministic. Levels top out at 7, so a level 7
    material asks for a level 8 result, finds none, and always fails.
--]]
function DigimonRules.getFusionResult(a, b)
    local colorsA = toSqlList(a:getColors())
    local colorsB = toSqlList(b:getColors())
    local sqlQuery =
        string.format(
        [[
        %s and
        c.level==%d and
        not exists (select 1 from card_colors x where x.card_id==c.card_id and x.color not in (%s)) and
        exists (select 1 from card_colors x where x.card_id==c.card_id and x.color in (%s)) and
        exists (select 1 from card_colors x where x.card_id==c.card_id and x.color in (%s)) and
        trait in (%s)
        order by (select count(*) from card_colors x where x.card_id==c.card_id) desc,
                 s.release_order desc,
                 c.card_id
        limit 1
        ]],
        selectCard,
        math.max(a:getLevel(), b:getLevel()) + 1,
        toSqlList(union(a:getColors(), b:getColors())),
        colorsA,
        colorsB,
        DigimonTraits.getSqlList(a:getTrait(), b:getTrait())
    )
    for data in database:nrows(sqlQuery) do
        return DigimonCardModel:new(data)
    end
end

--more DP wins
function DigimonRules.compareStats(a, b)
    if a:getPower() ~= b:getPower() then
        return a:getPower() > b:getPower() and 1 or -1
    end
    return 0
end

return DigimonRules
