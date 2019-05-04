--
-- For more information on config.lua see the Project Configuration Guide at:
-- https://docs.coronalabs.com/guide/basics/configSettings
--

local expectedRation = 1920 / 1080
local currentRatio = display.pixelHeight / display.pixelWidth
local ratioCorrection = expectedRation / currentRatio
application = {
	content = {
		width = 768 * ratioCorrection,
		height = 1024,
		scale = "letterbox",
		fps = 60
	}
}
