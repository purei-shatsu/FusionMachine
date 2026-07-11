--bakes the stat overlay into pics/<id>.jpg. Yu-Gi-Oh only: the Digimon art is
--prepared offline instead, by tools/convert_art.py.
local Database = require("Database")
local YugiohCardModel = require("YugiohCardModel")
local CardView = require("CardView")

local ImageGenerator = {}

function ImageGenerator.run()
	timer.performWithDelay(
		100,
		function()
			ImageGenerator.generateImages()
		end
	)
end

function ImageGenerator.generateImages()
	print("Generating card images...")
	local database = Database.open("cards.cdb")
	for cardData in database:nrows("select * from datas as d inner join texts as t on d.id==t.id") do
		local cardModel = YugiohCardModel:new(cardData)
		local cardView = CardView:new(cardModel, 1, 1)
		display.save(
			cardView.displayObject,
			{
				filename = "pics/" .. cardModel:getId() .. ".jpg",
				captureOffscreenArea = true
			}
		)
	end
	print("Done! Check the path: " .. system.pathForFile("pics", system.DocumentsDirectory))
end

return ImageGenerator
