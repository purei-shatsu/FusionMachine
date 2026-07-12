--[[
    A card's traits are the first two distinct groups among its card_types, in ord order.
    191 cards have more than two; they are capped. 824 of the 3,183 Digimon end up with two.

    Two vocabularies live in card_types, and only the first is worth fusing on:

        typings         Beast, Cyborg, Ice-Snow -- what the Digimon is made of. Always the
                        ord 0 type, on every one of the 3,183 Digimon.
        affiliations    Royal Knight, Xros, X-Antibody -- who it runs with. Only ever ord 1+.

    Both are grouped here, because DCGO's raw traits are far too fine-grained to fuse on --
    205 of them, with Dragon, Mini Dragon, Dragonkin and Beast Dragon all separate -- and the
    fusion rule compares groups.

    The rest is slop: markers that say which product a card came from rather than what it is
    (fusing on LIBERATOR would mean every EX11 card fuses with every other EX11 card), plus
    the affiliations whose cards all sit at one level. A fusion result is always one level
    above both materials, so a single-level group can never be the trait they share -- it is
    dead weight, and the cards keep whatever other trait they have.

    Every raw trait is in exactly one of the two tables. One that is in neither maps to nil
    and blows up, rather than being silently bucketed into the wrong group or silently
    dropped: a trait shipped by a future DCGO set is a decision, not a default.
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
        "Beast Knight",
        "ElusiveBeast"
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
        "Dragon Warrior",
        "Fire Dragon"
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
        "Ancient Fish",
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
    --Witchelny is the Wizardmon line's home world, and every card carrying it is already a
    --Wizard, so it collapses into the group instead of forming one
    Wizard = {
        "Wizard",
        "Shaman",
        "Witchelny"
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
    --the D-Reaper and its agents, worn only by the ADR-xx cards. The Seven Great Demon Lords
    --are all Demons already, so they collapse in here too
    Demon = {
        "Demon",
        "Demon Lord",
        "Demon God",
        "Evil",
        "Wicked God",
        "Fallen Angel",
        "AA Defense Agent",
        "Ability Synthesis Agent",
        "Base Defense Agent",
        "Commander Agent",
        "Espionage Agent",
        "Grappling Agent",
        "Ground Combat Agent",
        "Intel Acquisition Agent",
        "Mothership Agent",
        "Reconnaissance Agent",
        "Seven Great Demon Lords"
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
    --the angelic choirs. Seraphimon, Ophanimon and Cherubimon are the Three Great Angels,
    --and are Angels already, so that collapses in here
    Angel = {
        "Angel",
        "Archangel",
        "Seraph",
        "Cherub",
        "Throne",
        "Virtue",
        "Dominion",
        "Principality",
        "Omnipotence",
        "Three Great Angels"
    },
    --the one-off traits of the Appmon-style cards, each worn by a card or two
    App = {
        "Enhancement",
        "CRT",
        "Major",
        "Super Major",
        "Search",
        "Super Search",
        "Security",
        "Hacking",
        "Super Hacking",
        "Zip",
        "Unzip",
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
        "Online",
        "Offline",
        "Login",
        "Logoff",
        "Reboot",
        "Super Boot",
        "Forced Termination",
        "Design",
        "LCD",
        "Musical Instrument"
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
    },
    --the X-Antibody arc. "X-Antibody" is one card's spelling of "X Antibody", and X Program
    --is DeathXmon's counterpart to it
    ["X-Antibody"] = {
        "X Antibody",
        "X-Antibody",
        "X Program"
    },
    --every Xros Wars army, heroes and villains alike
    Xros = {
        "Xros Heart",
        "Blue Flare",
        "BlueFlare",
        "Bagra Army",
        "Twilight",
        "Legend-Arms",
        "Big Death-Stars"
    },
    ["Royal Knight"] = {
        "Royal Knight"
    },
    --the original virtual pet versions
    ["Ver."] = {
        "Ver.1",
        "Ver.2",
        "Ver.3",
        "Ver.4",
        "Ver.5"
    },
    SoC = {
        "SoC"
    },
    ["Olympos XII"] = {
        "Olympos XII"
    },
    Titan = {
        "Titan"
    },
    --the six virtual pet families, spelled out because the group name is printed on the card
    ["Nature Spirits"] = {
        "NSp"
    },
    ["Nightmare Soldiers"] = {
        "NSo"
    },
    ["Deep Savers"] = {
        "DS"
    },
    ["Wind Guardians"] = {
        "WG"
    },
    ["Metal Empire"] = {
        "ME"
    },
    ["Virus Busters"] = {
        "VB"
    },
    ["D-Brigade"] = {
        "D-Brigade"
    },
    ["Glowing Dawn"] = {
        "Glowing Dawn"
    },
    --the sun and moon lines (Coronamon to Apollomon, Lunamon to Dianamon) and GraceNovamon,
    --the fusion of the two, which is the only card carrying Galaxy
    Galaxy = {
        "Galaxy",
        "Night Claw",
        "Light Fang"
    },
    SW = {
        "SW"
    },
    TB = {
        "TB"
    },
    ACCEL = {
        "ACCEL"
    },
    Boss = {
        "Boss"
    },
    ["Vortex Warriors"] = {
        "Vortex Warriors"
    },
    ["Abadin Electronics"] = {
        "Abadin Electronics"
    },
    Leviathan = {
        "Leviathan"
    }
}

local slop = {
    --product markers: they say which set or story a card came from, not what it is. Fusing
    --on LIBERATOR would mean every EX11 card fuses with every other EX11 card
    "LIBERATOR",
    "TS",
    "CS",
    "Iliad",
    "DM",
    "ADVENTURE",
    "Shambala",
    "BEATBREAK",
    "DATA SQUAD",
    "SEEKERS",
    "Hero",
    --affiliations that can never be the trait a result shares with a material, so grouping
    --them would only be dead weight. These sit on a single level, and a result is always one
    --level above both materials
    "Deva",
    "Four Great Dragons",
    "Ten Warriors",
    "Four Sovereigns",
    "Three Musketeers",
    "Dark Masters",
    "Tentei Hachibushu",
    "Sanmyojin",
    "Saneiketsu",
    "Zaxon",
    "ADAMAS",
    --and these lose to the two-trait cap: every card carrying them already has two groups
    --ahead of them, so they reach a card's traits either never (Royal Base, Chronicle) or on
    --a single level (DigiPolice)
    "Royal Base",
    "Chronicle",
    "DigiPolice"
}

local DigimonTraits = {}

local maxTraits = 2

local groupOf = {}
for group, rawTraits in pairs(traits) do
    for _, rawTrait in ipairs(rawTraits) do
        groupOf[rawTrait] = group
    end
end

local isSlop = {}
for _, rawTrait in ipairs(slop) do
    isSlop[rawTrait] = true
end

--the first two distinct groups of a card's raw traits, which arrive in ord order. The five
--Eater cards are typed with nothing but slop and come back empty; they are level 0, so they
--never reach play anyway
function DigimonTraits.getGroups(rawTraits)
    local groups = {}
    for _, rawTrait in ipairs(rawTraits) do
        if not isSlop[rawTrait] then
            local group = groupOf[rawTrait]
            if not group then
                error(string.format("unknown trait '%s': group it in DigimonTraits, or slop it", rawTrait))
            end
            local seen = false
            for _, found in ipairs(groups) do
                if found == group then
                    seen = true
                end
            end
            if not seen then
                table.insert(groups, group)
                if #groups == maxTraits then
                    return groups
                end
            end
        end
    end
    return groups
end

return DigimonTraits
