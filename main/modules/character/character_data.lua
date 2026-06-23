-- ---@class PlayerStatsTable
-- ---@field strength number Сила
-- ---@field agility number Ловкость
-- ---@field intellect number Интеллект
-- ---@field stamina number Выносливость
--
-- ---@class PlayerPosition
-- ---@field x number Координата X в мире
-- ---@field y number Координата Y в мире
-- ---@field z number Координата Z в мире
--
-- ---@class ActionSlotData
-- ---@field action_type "ablity"|"item"|"empty" Тип действия в слоте
-- ---@field action_id string|nil            Строковый ID из базы способностей или предметов
--
-- ---@class PlayerDataStructure
-- ---@field name string Имя персонажа
-- ---@field race string Раса ("human", "orc", etc.)
-- ---@field class string Игровой класс ("warrior", "mage")
-- ---@field level number Текущий уровень
-- ---@field experience number Текущий опыт
-- ---@field health number Текущее здоровье (ХП)
-- ---@field max_health number Максимальное здоровье
-- ---@field mana number Текущая мана
-- ---@field max_mana number Максимальная мана
-- ---@field hitbox_size number
-- ---@field stats PlayerStatsTable Базовые характеристики расы/класса
-- ---@field current_stats PlayerStatsTable Текущие характеристики с учетом баффов/шмота
-- ---@field saved_position PlayerPosition 🚩 БЕТОННЫЙ ДЕФОЛТ: Последние координаты в мире
-- ---@field is_dead boolean
-- -- 🎯 ФИКС ТИПOВ ДЛЯ НEOВИМA:
-- -- Добавляем (ActionSlotData|nil)[] — теперь линтер знает, 
-- -- что пустые слоты на панели через nil абсолютно легальны!
-- ---@field action_bars table<number, (ActionSlotData|nil)[]> Матрица панелей способностей
--
-- ---@class CharacterDataModule
-- ---@field player PlayerDataStructure

-- main/modules/character/character_data.lua
-- 🎯 КРИСТАЛЬНАЯ ЧИСТОТА: Ровно один импорт Фасада! Код выглядит дорого и аккуратно.
local game_state = require("main.modules.game_state.game_state")

---@class CharacterDataModule
---@field player UnitInstanceData|table Наш гибридный указатель-мост
local M = {}

M.player = nil

---Инициализировать или принудительно связать игрока с единым Фасадом стейта
function M.bind_to_units_registry()
    -- Проверяем через Фасад, существует ли уже Юнит игрока в памяти RAM
    local current_player = game_state.get_player_data()

    if not current_player then
        -- 🌟 ВЕТКА НОВОЙ ИГРЫ: Игрока в памяти нет. Создаем его ЧЕРЕЗ ФАСАД game_state!
        -- Никаких прямых вызовов units_state! Поля выровнены под saved_position!
        current_player = game_state.create_player_unit({
            unit_id = "player_mage",
            level = 1,
            type = "humanoid",
            rank = "common",
            loot_table_id = "empty",
            saved_position = vmath.vector3(0, 0, 1.0) -- 🛡️ Единое каноничное имя saved_position!
        })
        
        -- Доливаем специфичные для плеера дефолты в созданную ячейку RAM
        if current_player then
            current_player.name_key = "class_mage"
            current_player.is_player = true
            current_player.experience = 0
            current_player.action_bars = {}
            current_player.stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
            current_player.current_stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
        end
    end

    -- НАМЕРТВО СВЯЗЫВАЕМ ССЫЛКУ-МОСТ
    M.player = current_player
end

-- Автоматически принудительно биндим ссылку при первом обращении к модулю
M.bind_to_units_registry()

function M.update_from_config()
    -- Твоя логика...
end

return M



