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

local music = {
    audio.loadStream("musics/Egyptian Duel.mp3"),
    audio.loadStream("musics/Free Duel.mp3"),
    audio.loadStream("musics/Preliminary Match.mp3"),
    audio.loadStream("musics/Priest Seto Theme.mp3"),
    audio.loadStream("musics/Seto Kaiba.mp3")
}

function Sound.play(name)
    audio.play(sound[name])
end

function Sound.playMusic(id)
    audio.play(
        music[id],
        {
            channel = 1,
            loops = -1
        }
    )
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

        for i, s in pairs(music) do
            audio.dispose(s)
        end
        music = nil
    end
)

--play music
Sound.playMusic(math.random(#music))
audio.setVolume(0.30, {channel = 1})

return Sound
