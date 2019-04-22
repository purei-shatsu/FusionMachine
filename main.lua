--[[Game Rules
Very modified:
	Can only play each zone once per turn (prevents boring semi-safe fusions)
	Can play a max of 8 stars from hand per turn
Slightly modified
	Can only play one card/fusion per turn (same as original)
	[MAYBE] Total levels of cards in the deck can't go over a certain value
		Provavelmente é desnecessário, já é melhor usar cartas com atk 0 pra fazer fusões rápidas
Only monsters with atk<=3000 and def<=3000 can go into the main deck (the rest can only be obtained through fusion)
Rest are Forbidden Memories rules
[TODO Spells/equips/traps]
--]]
--[[TODO
Effects:
	Particles
]]
local sqlite3 = require("sqlite3")
local CardModel = require("src.CardModel")
local CardView = require("src.CardView")
local Sound = require("src.Sound")
local MemoryCleaner = require("src.MemoryCleaner")
local FusionProcessor = require("src.FusionProcessor")
local Animator = require("src.Animator")
require("src.Utils.Utils")

local path = system.pathForFile("cards.cdb")
local zero = 1e-5

local db = sqlite3.open(path)
MemoryCleaner.register(
	function()
		db:close()
	end
)
FusionProcessor.setDatabase(db)

--[[
for card in db:nrows('select * from datas as d inner join texts as t on d.id==t.id order by atk,def') do
	print(card.name, card.level, card.atk, card.def)
end
--]]
local hand = {}
local materials = {}

--TODO move to Sound.lua
function playSoundF(name)
	return function()
		Sound.play(name)
	end
end

--select five non-special cards for starting hand
for cardData in db:nrows(
	"select * from datas as d inner join texts as t on d.id==t.id and atk<=2000 and def<=2000 order by random() limit 5"
) do
	local cardModel = CardModel:new(cardData)
	local cardView = CardView:new(cardModel, #hand + 1, materials)
	hand[#hand + 1] = cardView
	cardView:moveToHand(#hand)

	--TODO DELETA ISSO
	cardView:markAsMaterial()
end

--keyboard
Runtime:addEventListener(
	"key",
	function(event)
		if event.keyName == "space" and event.phase == "down" and #materials > 0 then
			Sound.play("confirm")

			--prepare Animator parameters
			local modelMaterials = {}
			local viewMaterials = {}
			for i, cardView in ipairs(materials) do
				viewMaterials[i] = cardView
				modelMaterials[i] = cardView:getModel()
			end
			local results = FusionProcessor.performFusion(modelMaterials)

			--remove cards from materials
			for i = #materials, 1, -1 do
				materials[i]:unmarkAsMaterial(true)
			end

			--fuse
			Animator.performFusion(hand, viewMaterials, results)
		end
		if event.keyName == "x" then
			slow = event.phase == "down" and 4 or 1
		end
	end
)
