local sqlite3 = require("sqlite3")
local MemoryCleaner = require("MemoryCleaner")

local path = system.pathForFile("cards.cdb")
local Database = sqlite3.open(path)
MemoryCleaner.register(
    function()
        Database:close()
    end
)

-- for card in Database:nrows('select * from datas as d inner join texts as t on d.id==t.id order by atk,def') do
-- 	print(card.name, card.level, card.atk, card.def)
-- end

return Database
