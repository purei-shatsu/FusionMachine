local Class = require("src.Utils.Class")

local CardModel =
    Class.new(
    {},
    function(self, data)
        self.data = data
    end
)

function CardModel:getId()
    return self.data.id
end

function CardModel:getName()
    return self.data.name
end

function CardModel:getAttack()
    return self.data.atk
end

function CardModel:getDefense()
    return self.data.def
end

function CardModel:getRace()
    return self.data.race
end

function CardModel:getAttribute()
    return self.data.attribute
end

return CardModel
