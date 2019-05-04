local MemoryCleaner = require("MemoryCleaner")

local Sound = {}

local sound = {
    confirm = audio.loadSound("sounds/confirm.mp3"),
    material = audio.loadSound("sounds/material.mp3"),
    move = audio.loadSound("sounds/move.mp3"),
    discard = audio.loadSound("sounds/discard.mp3"),
    fusion = audio.loadSound("sounds/fusion.mp3"),
    fusionEnd = audio.loadSound("sounds/fusionEnd.mp3")
}

function Sound.play(name)
    audio.play(sound[name])
end

function Sound.playWrapper(name)
    return function()
        Sound.play(name)
    end
end

MemoryCleaner.register(
    function()
        for i, s in pairs(sound) do
            audio.dispose(s)
        end
        sound = nil
    end
)

return Sound
