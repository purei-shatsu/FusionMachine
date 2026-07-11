--[[
    Picks which game is being played. main.lua calls set() before requiring anything
    else, because the rules module opens its database as a side effect of being loaded.

    Everything mode-specific lives behind rules(), which answers three questions:
        drawCards(amount)       -> array of card models, the random hand pull
        getFusionResult(a, b)   -> a card model, or nil when the pair fuses into nothing
        compareStats(a, b)      -> 1, -1 or 0; which of two fusion results the AI prefers

    The cards they hand back are CardModel subclasses; see CardModel.lua for the five
    methods the rest of the game is allowed to know about.
--]]
local GameMode = {}

local rulesModules = {
    yugioh = "YugiohRules",
    digimon = "DigimonRules"
}

function GameMode.set(name)
    GameMode.name = name
    GameMode.rulesModule = rulesModules[name]
end

function GameMode.rules()
    return require(GameMode.rulesModule)
end

return GameMode
