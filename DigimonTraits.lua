--[[
    A card's trait is its first card_types row (ord == 0); the others are ignored, so
    Coronamon (Beast/Illiad/TS) is simply a Beast.

    DCGO's raw traits are far too fine-grained to fuse on -- 190 of them, with Dragon,
    Mini Dragon, Dragonkin and Beast Dragon all separate -- so they are grouped here and
    the fusion rule compares groups. Every raw trait belongs to exactly one group: a trait
    added by a future DCGO set maps to nil and blows up, rather than being silently
    bucketed into the wrong group.
--]]
local traits = {
    Beast = {
        "Beast",
        "Beastkin",
        "Holy Beast",
        "Mythical Beast",
        "Mysterious Beast",
        "God Beast",
        "Dark Animal",
        "Mammal",
        "Ancient Animal",
        "Ancient Mythical Beast",
        "Beast Knight"
    },
    Machine = {
        "Machine",
        "Cyborg",
        "Armor",
        "Weapon"
    },
    Dragon = {
        "Dragon",
        "Mini Dragon",
        "Dragonkin",
        "Ancient Dragon",
        "Ancient Dragonkin",
        "Dark Dragon",
        "Evil Dragon",
        "Holy Dragon",
        "Light Dragon",
        "Sky Dragon",
        "Earth Dragon",
        "Rock Dragon",
        "Machine Dragon",
        "Mythical Dragon",
        "Beast Dragon",
        "Bird Dragon",
        "Dragon Warrior"
    },
    --Reptile is the Agumon line, and digivolves into Dinosaur
    Dinosaur = {
        "Dinosaur",
        "Ceratopsian",
        "Ankylosaur",
        "Reptile",
        "Reptile Man"
    },
    Warrior = {
        "Warrior",
        "Holy Warrior",
        "Ancient Holy Warrior",
        "Dark Knight",
        "Magic Knight",
        "Magic Warrior",
        "Monk",
        "Fighting",
        "Holy Sword"
    },
    Aquatic = {
        "Aquatic",
        "Sea Animal",
        "Sea Beast",
        "Aquabeast",
        "Ancient Aquabeast",
        "Mollusk",
        "Crustacean",
        "Ancient Crustacean",
        "Tropical Fish",
        "Amphibian",
        "Marine Man",
        "Plesiosaur"
    },
    Insect = {
        "Insectoid",
        "Larva",
        "Parasite",
        "Ancient Insect"
    },
    Mutant = {
        "Mutant",
        "Ancient Mutant",
        "Composite",
        "Abnormal",
        "Alien",
        "Alien Humanoid",
        "Invader"
    },
    Puppet = {
        "Puppet"
    },
    Wizard = {
        "Wizard",
        "Shaman"
    },
    Unknown = {
        "Unknown",
        "Unidentified",
        "Unique",
        "Unanalyzable",
        "???",
        "NO DATA",
        "NODATA",
        "Ancient",
        "Perfect",
        "9000",
        "Tathāgata"
    },
    Demon = {
        "Demon",
        "Demon Lord",
        "Demon God",
        "Evil",
        "Wicked God",
        "Fallen Angel"
    },
    Bird = {
        "Bird",
        "Birdkin",
        "Avian",
        "Giant Bird",
        "Holy Bird",
        "Mysterious Bird",
        "Ancient Bird",
        "Ancient Birdkin"
    },
    --the angelic choirs
    Angel = {
        "Angel",
        "Archangel",
        "Seraph",
        "Cherub",
        "Throne",
        "Virtue",
        "Dominion",
        "Principality",
        "Omnipotence"
    },
    --the one-off traits of the Appmon-style cards, each worn by a card or two
    App = {
        "Enhancement",
        "CS",
        "CRT",
        "Major",
        "Super Major",
        "Search",
        "Super Search",
        "Security",
        "Hacking",
        "Super Hacking",
        "Zip",
        "Wallpaper",
        "Tweet",
        "SNS",
        "Music",
        "Media Player",
        "Navi",
        "GPS",
        "Clock",
        "Calendar",
        "Broadcasting",
        "Recording",
        "Monitoring",
        "Mirror",
        "Mind Control",
        "Copy & Paste",
        "Coordinate",
        "Camouflage",
        "Gossip",
        "Global",
        "Galaxy",
        "Entertainment",
        "Doctor",
        "Medical",
        "Life",
        "Invincible",
        "Dream",
        "Creation",
        "Beauty",
        "Battle",
        "Awakening",
        "Avatar",
        "Authority",
        "Astronomy",
        "Action",
        "Effect",
        "Weather",
        "Warning",
        "Voice Change",
        "Transmutation",
        "Transmission",
        "Training",
        "Time Slip",
        "Strategy",
        "Stealth",
        "Simulation",
        "Shooting",
        "Saving",
        "Restoration",
        "Muscle Training",
        "AA Defense Agent",
        "Base Defense Agent",
        "Commander Agent",
        "Espionage Agent",
        "Ground Combat Agent",
        "Intel Acquisition Agent"
    },
    Plant = {
        "Vegetation",
        "Carnivorous Plant",
        "Ancient Plant"
    },
    Undead = {
        "Undead",
        "Ghost"
    },
    Fairy = {
        "Fairy",
        "Ancient Fairy"
    },
    Mineral = {
        "Mineral",
        "Rock",
        "Mine",
        "Ancient Mineral"
    },
    Flame = {
        "Flame"
    },
    ["Ice-Snow"] = {
        "Ice-Snow"
    },
    Food = {
        "Food",
        "Gourmet"
    },
    Hudie = {
        "Hudie"
    }
}

local DigimonTraits = {}

local groupOf = {}
local sqlListOf = {}
for group, rawTraits in pairs(traits) do
    local quoted = {}
    for _, rawTrait in ipairs(rawTraits) do
        groupOf[rawTrait] = group
        table.insert(quoted, string.format("'%s'", rawTrait))
    end
    sqlListOf[group] = table.concat(quoted, ",")
end

function DigimonTraits.getGroup(rawTrait)
    return groupOf[rawTrait]
end

--every raw trait of both groups, as an SQL list to match card_types.type_en against.
--No trait name carries an apostrophe, so quoting them is enough
function DigimonTraits.getSqlList(groupA, groupB)
    if groupA == groupB then
        return sqlListOf[groupA]
    end
    return sqlListOf[groupA] .. "," .. sqlListOf[groupB]
end

return DigimonTraits
