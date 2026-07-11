local sqlite3 = require("sqlite3")
local MemoryCleaner = require("MemoryCleaner")

local Database = {}

function Database.open(filename)
    local database = sqlite3.open(system.pathForFile(filename))
    MemoryCleaner.register(
        function()
            database:close()
        end
    )
    return database
end

return Database
