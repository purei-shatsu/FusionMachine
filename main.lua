package.path = string.format("%s\\src\\?.lua;%s", system.pathForFile(nil, system.ResourcesDirectory), package.path)

require("src.Utils.SmartRequire")
require("src.Utils.Utils")
local Game = require("Game")

local game = Game:new()
game:runPlayerTurn()
