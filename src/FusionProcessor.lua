local CardModel = require("CardModel")
local Database = require("Database")

local FusionProcessor = {}

function FusionProcessor.performFusion(materials)
    local results = {}

    local materialA = materials[1]
    for i = 2, #materials do
        --use second material as result if fusion failed
        local materialB = materials[i]
        local result = FusionProcessor._getFusionResult(materialA, materialB) or materialB
        table.insert(results, result)

        --use result as first material for next fusion
        materialA = result
    end

    return results
end

function FusionProcessor._getFusionResult(a, b)
    --[[
        Fusion Conditions:
            Type from one and attribute from the other;
            Attack no bigger than total defense;
            Attack bigger than both attacks or (attack equal to biggest attack and defense bigger than both defenses).
        Order by: Attack, Defense, Id
        --]]
    local sqlQuery =
        string.format(
        [[
		select * from datas as d inner join texts as t on d.id==t.id where
		((race==%d and attribute==%d) or (race==%d and attribute==%d)) and
		atk<=%d and (atk>%d or (atk==%d and def>%d))
		order by atk desc,def desc,id limit 1
		]],
        a:getRace(),
        b:getAttribute(),
        b:getRace(),
        a:getAttribute(),
        a:getDefense() + b:getDefense(),
        math.max(a:getAttack(), b:getAttack()),
        math.max(a:getAttack(), b:getAttack()),
        math.max(a:getDefense(), b:getDefense())
    )
    for data in Database:nrows(sqlQuery) do
        return CardModel:new(data)
    end
end

return FusionProcessor
