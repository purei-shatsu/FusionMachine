local generateImages = false

require("Utils.SmartRequire")
require("Utils.Utils")

if not generateImages then
	local Game = require("Game")
	local game = Game:new()
	game:runPlayerTurn()
else
	local ImageGenerator = require("ImageGenerator")
	ImageGenerator.run()
end
