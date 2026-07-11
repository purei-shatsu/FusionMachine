local gameMode = "digimon" --"yugioh" or "digimon"
local generateImages = false

require("Utils.SmartRequire")
require("Utils.Utils")

--must come before anything else, because the rules module opens its database as a
--side effect of being required
require("GameMode").set(gameMode)

if not generateImages then
	local Game = require("Game")
	local game = Game:new()
	game:runPlayerTurn()
else
	local ImageGenerator = require("ImageGenerator")
	ImageGenerator.run()
end
