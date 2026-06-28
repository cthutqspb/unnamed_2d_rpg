local game_state = require("main.modules.game_state.game_state")

---@class CharacterDataModule
---@field player UnitInstanceData|table|nil Наш гибридный указатель-мост
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
            saved_position = vmath.vector3(0, 0, 1.0), -- 🛡️ Единое каноничное имя saved_position!
            -- Буфер инвентаря...
            inventory = nil,
        })

        -- Доливаем специфичные для плеера дефолты в созданную ячейку RAM
        if current_player then
            current_player.name_key = "class_mage"
            current_player.is_player = true
            current_player.experience = 0
            current_player.action_bars = {}
            current_player.base_stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
            current_player.current_stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
        end
    end

    -- НАМЕРТВО СВЯЗЫВАЕМ ССЫЛКУ-МОСТ
    M.player = current_player
end

-- Автоматически принудительно биндим ссылку при первом обращении к модулю
M.bind_to_units_registry()

---Покадрово зафиксировать и защитить новые координаты игрока в RAM-памяти бэкенда
---@param position vector3 Текущие нативные Си-координаты из go.get_position()
function M.update_position(position)
    -- Элегантный сквозной проброс через Фасад вселенной!
    game_state.update_player_position(position)
end

function M.update_from_config()
    -- Твоя логика...
end

---Проверить, активен ли ГКД у игрока (проброс для player.script)
---@return boolean
function M.is_gcd_active()
    -- Вежливо проверяем поле прямо у нашей локальной ссылки M.player
    local p = M.player
    return (p and p.gcd_current and p.gcd_current > 0) or false
end

---Запустить ГКД для игрока на бэкенде
---@param duration number Время в секундах (1.5)
function M.start_gcd(duration)
    local p = M.player
    if p then
        p.gcd_current = duration
    end
end

return M



