---@class PlayerStatsTable
---@field strength number Сила
---@field agility number Ловкость
---@field intellect number Интеллект
---@field stamina number Выносливость

---@class PlayerPosition
---@field x number Координата X в мире
---@field y number Координата Y в мире

---@class PlayerDataStructure
---@field name string Имя персонажа
---@field race string Раса ("human", "orc", etc.)
---@field class string Игровой класс ("warrior", "mage")
---@field level number Текущий уровень
---@field experience number Текущий опыт
---@field health number Текущее здоровье (ХП)
---@field max_health number Максимальное здоровье
---@field mana number Текущая мана
---@field max_mana number Максимальная мана
---@field stats PlayerStatsTable Базовые характеристики расы/класса
---@field current_stats PlayerStatsTable Текущие характеристики с учетом баффов/шмота
---@field last_pos PlayerPosition 🚩 БЕТОННЫЙ ДЕФОЛТ: Последние координаты в мире

---@class CharacterDataModule
---@field player PlayerDataStructure
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
    },
    current_stats = {
        strength = 10,
        agility = 10,
        intellect = 10,
        stamina = 10
    },
    -- 🚩 ФИКС: Безопасные стартовые координаты, спасающие от nil-крашей при загрузке
    last_pos = { x = 0, y = 0 }
}

---Обновить базовые и текущие характеристики персонажа на основе конфигурационных файлов
function M.update_from_config()
    local race_data = require("main.modules.character.character_config").races[M.player.race]
    local class_data = require("main.modules.character.character_config").classes[M.player.class]

    -- Соединяем базовые статы расы и класса (если нужно)
    -- ...
end

return M

