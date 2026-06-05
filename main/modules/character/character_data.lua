---@class PlayerStatsTable
---@field strength number Сила
---@field agility number Ловкость
---@field intellect number Интеллект
---@field stamina number Выносливость

---@class PlayerPosition
---@field x number Координата X в мире
---@field y number Координата Y в мире

---@class ActionSlotData
---@field action_type "spell"|"item"|"empty" Тип действия в слоте
---@field action_id string|nil            Строковый ID из базы способностей или предметов

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
---@field hitbox_size number
---@field stats PlayerStatsTable Базовые характеристики расы/класса
---@field current_stats PlayerStatsTable Текущие характеристики с учетом баффов/шмота
---@field last_pos PlayerPosition 🚩 БЕТОННЫЙ ДЕФОЛТ: Последние координаты в мире
---@field is_dead boolean
-- 🎯 ФИКС ТИПOВ ДЛЯ НEOВИМA:
-- Добавляем (ActionSlotData|nil)[] — теперь линтер знает, 
-- что пустые слоты на панели через nil абсолютно легальны!
---@field action_bars table<number, (ActionSlotData|nil)[]> Матрица панелей способностей

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
    hitbox_size = 64,
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
    last_pos = { x = 0, y = 0 },
    is_dead = false,

    -- 🎯 МАТРИЦА ПАНЕЛЕЙ СПОСОБНОСТЕЙ (Индексы строго с 1):
    action_bars = {}
}

---Обновить базовые и текущие характеристики персонажа на основе конфигурационных файлов
function M.update_from_config()
    local race_data = require("main.modules.character.character_config").races[M.player.race]
    local class_data = require("main.modules.character.character_config").classes[M.player.class]

    -- Соединяем базовые статы расы и класса (если нужно)
    -- ...
end

return M

