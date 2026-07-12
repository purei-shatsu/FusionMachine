--[[
    Base class for a card of either game. Holds the raw database row; every accessor
    is defined by the subclass, because the two databases have nothing in common at
    the column level.

    Subclasses (YugiohCardModel, DigimonCardModel) must implement:
        getId()             identity
        getName()
        getPower()          the single stat that decides battles (atk / DP)
        getImagePath()      the card art
        getDisplayText()    the two lines CardText paints over the art
        getTextPosition()   x, y of that text box, since the two arts print their stats
                            in different places

    Anything beyond that is the mode's own business, and only its own Rules reads it.
--]]
local Class = require("Utils.Class")

local CardModel =
    Class.new(
    {},
    function(self, data)
        self.data = data
    end
)

return CardModel
