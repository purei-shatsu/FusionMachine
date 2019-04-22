--[[
    CardLocator is a class that stores where every card is.
    It keeps their locations and positions consitent with each other.
--]]
local Class = require("src.Utils.Class")

local CardLocator =
    Class.new(
    {},
    function(self)
        self.card = {} --[CardB] = {location="deck", position=2}
        self.location = {} --["deck"] = {CardA, CardB}
        self.count = {} --["deck"] = 2
        self.options = {} --["table"] = {allowHoles = true}
    end
)

function CardLocator:createLocation(locationName, options)
    --create location if not exists yet
    local location = self.location[locationName]
    if not location then
        self.options[locationName] = options or {}
        self.location[locationName] = {}
        self.count[locationName] = 0

        location = self.location[locationName]
    end
    return location
end

function CardLocator:insertCard(card, locationName, position)
    --remove card from previous location
    self:removeCard(card)

    --create location
    local location = self:createLocation(locationName)

    --use position if provided
    --otherwise, insert at next available space
    position = position or #location + 1
    if not self.options[locationName].allowHoles then
        --snap to next position if would create a hole
        position = math.min(position, #location + 1)
    end
    table.insert(location, position, card)

    --update card location
    self.card[card] = {
        location = locationName,
        position = position
    }

    --increment count
    self.count[locationName] = self.count[locationName] + 1
end

function CardLocator:removeCard(card)
    --get card previous location and position
    local locationName = self:getCardLocation(card)
    local position = self:getCardPosition(card)
    if locationName then
        local location = self.location[locationName]

        --remove card
        if self.options[locationName].allowHoles then
            location[position] = nil
        else
            table.remove(location, position)

            --update following cards position
            for i = position, #location do
                local otherCard = location[i]
                local info = self.card[otherCard]
                info.position = info.position - 1
            end
        end
        self.card[card] = nil

        --decrement count
        self.count[locationName] = self.count[locationName] - 1
    end
end

function CardLocator:getCardLocation(card)
    local info = self.card[card]
    return info and info.location or nil
end

function CardLocator:getCardPosition(card)
    local info = self.card[card]
    return info and info.position or nil
end

function CardLocator:getLocationCount(locationName)
    return self.count[locationName] or 0
end

function CardLocator:getCardsInLocation(locationName)
    local cards = {}
    for i, card in pairs(self.location[locationName] or {}) do
        cards[i] = card
    end
    return cards
end

return CardLocator
