local Database = require("Database")
local DigimonCardModel = require("DigimonCardModel")
local DigimonTraits = require("DigimonTraits")

local DigimonRules = {}

local database = Database.open("digimon.cdb")

--only Digimon cards. Cards with no art are played anyway, standing in as a white rectangle
local drawLevel = 3

--the card pool the game plays with, e.g. {"BT24", "EX11"}. Empty means every set.
--restricts both the drawn hands and the fusion results
local drawSets = {"EX11"}

local function toSqlList(colors)
    return table.concat(colors, ",")
end

--no trait group carries an apostrophe, so quoting the names is enough
local function toSqlTextList(traits)
    local quoted = {}
    for _, trait in ipairs(traits) do
        table.insert(quoted, string.format("'%s'", trait))
    end
    return table.concat(quoted, ",")
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

--[[
    The trait groups of every Digimon, resolved once through DigimonTraits into a temp table.
    They cannot be stored in the database: a card's traits are the first two distinct groups
    of its card_types, and both the grouping and the cap are rules, which live here rather
    than in the import. SQL cannot derive them, but the fusion query has to filter on them.
--]]
local function buildTraitIndex()
    database:exec("create temp table card_traits (card_id text, trait text)")
    database:exec("create index card_traits_by_card on card_traits(card_id)")

    local cardIds = {}
    local rawTraits = {}
    local sqlQuery =
        [[
        select t.card_id, t.type_en from card_types as t inner join cards as c on c.card_id==t.card_id
        where c.card_kind==0
        order by t.card_id, t.ord
        ]]
    for data in database:nrows(sqlQuery) do
        if not rawTraits[data.card_id] then
            rawTraits[data.card_id] = {}
            table.insert(cardIds, data.card_id)
        end
        table.insert(rawTraits[data.card_id], data.type_en)
    end

    database:exec("begin")
    for _, cardId in ipairs(cardIds) do
        for _, trait in ipairs(DigimonTraits.getGroups(rawTraits[cardId])) do
            database:exec(string.format("insert into card_traits values ('%s','%s')", cardId, trait))
        end
    end
    database:exec("commit")
end

buildTraitIndex()

--colors and traits both live in a child table, so pull them back with the row as "0,5" and
--"Machine,Insect", and the whole card comes back in a single row
local selectCard =
    [[
    select c.*, (select group_concat(color) from card_colors x where x.card_id==c.card_id) as colors,
                (select group_concat(trait) from card_traits x where x.card_id==c.card_id) as traits
    from cards as c inner join sets as s on s.set_code==c.set_code
    where c.card_kind==0
    ]] ..
    drawSetsClause()

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
        The result shares a trait with one material and a colour with the other.
    Order by: newest set, id

    The result may carry colours neither material has: Tyrannomon (Red/Green) is a legal result of
    Impmon (Purple/Red) and Sunarizamon (Black), taking Red from the first and Dinosaur from the
    second, and its Green is free.

    Every condition is symmetric in a and b, so the fusion is commutative, and the ordering is
    total, so it is deterministic. Levels top out at 7, so a level 7 material asks for a level
    8 result, finds none, and always fails.
--]]
function DigimonRules.getFusionResult(a, b)
    local colorsA = toSqlList(a:getColors())
    local colorsB = toSqlList(b:getColors())
    local traitsA = toSqlTextList(a:getTraits())
    local traitsB = toSqlTextList(b:getTraits())
    local sqlQuery =
        string.format(
        [[
        %s and
        c.level==%d and
        ((exists (select 1 from card_traits x where x.card_id==c.card_id and x.trait in (%s)) and
          exists (select 1 from card_colors x where x.card_id==c.card_id and x.color in (%s))) or
         (exists (select 1 from card_traits x where x.card_id==c.card_id and x.trait in (%s)) and
          exists (select 1 from card_colors x where x.card_id==c.card_id and x.color in (%s))))
        order by s.release_order desc,
                 c.card_id
        limit 1
        ]],
        selectCard,
        math.max(a:getLevel(), b:getLevel()) + 1,
        traitsA,
        colorsB,
        traitsB,
        colorsA
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
