local Class = require("Utils.Class")
local CardModel = require("CardModel")

--race and attribute are bitflags in the YGOPro database
local attributes = {
    [1] = "EARTH",
    [2] = "WATER",
    [4] = "FIRE",
    [8] = "WIND",
    [16] = "LIGHT",
    [32] = "DARK",
    [64] = "???"
}
local races = {
    [1] = "Warrior",
    [2] = "Spellc",
    [4] = "Fairy",
    [8] = "Fiend",
    [16] = "Zombie",
    [32] = "Machine",
    [64] = "Aqua",
    [128] = "Pyro",
    [256] = "Rock",
    [512] = "Winged",
    [1024] = "Plant",
    [2048] = "Insect",
    [4096] = "Thunder",
    [8192] = "Dragon",
    [16384] = "Beast",
    [32768] = "Bst-W.",
    [65536] = "Dino.",
    [131072] = "Fish",
    [262144] = "Sea S.",
    [524288] = "Reptile",
    [1048576] = "Psychic",
    [2097152] = "Divine",
    [4194304] = "???",
    [8388608] = "Wyrm",
    [16777216] = "Cyberse"
}

local YugiohCardModel =
    Class.new(
    {},
    function(self)
    end,
    CardModel
)

function YugiohCardModel:getId()
    return self.data.id
end

function YugiohCardModel:getName()
    return self.data.name
end

function YugiohCardModel:getPower()
    return self.data.atk
end

function YugiohCardModel:getImagePath()
    return "pics/" .. self.data.id .. ".jpg"
end

function YugiohCardModel:getDisplayText()
    return string.format(
        "%s / %s\n%4d / %4d",
        races[self:getRace()] or "???",
        attributes[self:getAttribute()] or "???",
        self:getAttack(),
        self:getDefense()
    )
end

function YugiohCardModel:getAttack()
    return self.data.atk
end

function YugiohCardModel:getDefense()
    return self.data.def
end

function YugiohCardModel:getRace()
    return self.data.race
end

function YugiohCardModel:getAttribute()
    return self.data.attribute
end

return YugiohCardModel
