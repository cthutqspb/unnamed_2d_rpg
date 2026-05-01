--local character_config = require("main.modules.character_config")

local M = {}

M.player = {
    name = "Unknown",
    race = "human",
    class = "warrior",
    level = 1,
    experience = 0,
    health = 100,
    max_health = 100,
    mana = 50,
    max_mana = 50,
    stats = {
        strength = 10,
        agility = 10,
        intellect = 10,
        stamina = 10
    }
}

function M.update_from_config()
    local race_data = require("main.modules.character_config").races[M.player.race]
    local class_data = require("main.modules.character_config").classes[M.player.class]
    
    -- Соединяем базовые статы расы и класса (если нужно)
    -- ...
end

return M
