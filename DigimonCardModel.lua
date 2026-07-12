local Class = require("Utils.Class")
local CardModel = require("CardModel")

--colors arrive as the group_concat of card_colors (e.g. "0,5") and traits as the group_concat
--of DigimonRules' trait index (e.g. "Machine,Insect"), so the whole card comes back in a
--single row
local DigimonCardModel =
    Class.new(
    {},
    function(self, data)
        self.colors = {}
        for color in string.gmatch(data.colors, "%d+") do
            table.insert(self.colors, tonumber(color))
        end
        self.traits = {}
        for trait in string.gmatch(data.traits, "[^,]+") do
            table.insert(self.traits, trait)
        end
    end,
    CardModel
)

function DigimonCardModel:getId()
    return self.data.card_id
end

function DigimonCardModel:getName()
    return self.data.name_en
end

function DigimonCardModel:getPower()
    return self.data.dp
end

function DigimonCardModel:getImagePath()
    return "digimon_pics/" .. self.data.card_id .. ".jpg"
end

function DigimonCardModel:getDisplayText()
    return string.format("%s\nLv %d / DP %d", table.concat(self.traits, "/"), self:getLevel(), self:getPower())
end

function DigimonCardModel:getTextPosition()
    return 0, 65
end

function DigimonCardModel:getTextSize()
    return 250, 80
end

function DigimonCardModel:getLevel()
    return self.data.level
end

function DigimonCardModel:getColors()
    return self.colors
end

function DigimonCardModel:getTraits()
    return self.traits
end

return DigimonCardModel
