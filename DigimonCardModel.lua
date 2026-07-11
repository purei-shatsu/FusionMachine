local Class = require("Utils.Class")
local CardModel = require("CardModel")

--colors arrive as the group_concat of card_colors (e.g. "0,5"), so the whole card
--comes back in a single row
local DigimonCardModel =
    Class.new(
    {},
    function(self, data)
        self.colors = {}
        for color in string.gmatch(data.colors, "%d+") do
            table.insert(self.colors, tonumber(color))
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
    return string.format("Lv %d\nDP %d", self:getLevel(), self:getPower())
end

function DigimonCardModel:getLevel()
    return self.data.level
end

function DigimonCardModel:getColors()
    return self.colors
end

return DigimonCardModel
