package.path = string.format("%s\\src\\?.lua;%s", system.pathForFile(nil, system.ResourcesDirectory), package.path)

require("Utils.SmartRequire")
require("Utils.Utils")
local Game = require("Game")

local game = Game:new()
game:runPlayerTurn()
