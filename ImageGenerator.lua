local Database = require("Database")
local CardModel = require("CardModel")
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
	for cardData in Database:nrows("select * from datas as d inner join texts as t on d.id==t.id") do
		local cardModel = CardModel:new(cardData)
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
