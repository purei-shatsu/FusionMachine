local GameMode = require("GameMode")

local FusionProcessor = {}

--fuses left to right, feeding each result back in as the first material of the next
--fusion. A failed fusion falls through to its second material.
function FusionProcessor.performFusion(materials)
    local results = {}

    local materialA = materials[1]:getModel()
    for i = 2, #materials do
        --use second material as result if fusion failed
        local materialB = materials[i]:getModel()
        local result = GameMode.rules().getFusionResult(materialA, materialB) or materialB
        table.insert(results, result)

        --use result as first material for next fusion
        materialA = result
    end

    return results
end

return FusionProcessor
