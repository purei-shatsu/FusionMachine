--TODO use a relative path instead of this
package.path = "C:\\Users\\lucas\\Documents\\Corona Projects\\Fusion Machine\\src\\?.lua;" .. package.path

require("Utils.SmartRequire")
require("Utils.Utils")
local Game = require("Game")

local game = Game:new()
game:runTurn()
