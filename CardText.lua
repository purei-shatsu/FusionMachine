local Class = require("Utils.Class")

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

local CardText =
    Class.new(
    {
        width = 225,
        height = 72
    },
    function(self, model)
        self.displayObject = display.newGroup()
        self.displayObject.x = 0
        self.displayObject.y = 132

        display.newRect(self.displayObject, 0, 0, 225, 72)

        local attribute = attributes[model:getAttribute()] or "???"
        local race = races[model:getRace()] or "???"
        local text =
            display.newText(
            {
                parent = self.displayObject,
                text = string.format("%s / %s\n%4d / %4d", race, attribute, model:getAttack(), model:getDefense()),
                width = self.width,
                fontSize = 27,
                align = "center"
            }
        )
        text:setFillColor(0, 0, 0)
    end
)

function CardText:hide()
    self.displayObject.isVisible = false
end

function CardText:show()
    self.displayObject.isVisible = true
end

return CardText
