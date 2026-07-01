local game_state = require("main.modules.game_state.game_state")
local units_state = require("main.modules.game_state.units_state")

---@class CharacterDataModule
---@field player UnitInstanceData|table|nil Наш гибридный указатель-мост
local M = {}

M.PLAYER_UID = "player"
M.player = nil

function M.bind_to_units_registry()
    -- Проверяем через Фасад, существует ли уже Юнит игрока в памяти RAM
    local current_player = game_state.get_entity_by_uid(M.PLAYER_UID)

    if not current_player then
        -- 🌟 ВЕТКА ТЕСТА ИЗ РЕДАКТОРА (До нажатия кнопки "Новая Игра"):
        -- Игрока в памяти нет. Рожаем его Душу ПОЛНОЦЕННО и сочно, 
        -- вызывая наш единый бэкенд-конструктор юнитов units_state.add!
        -- Теперь у мага АВТОМАТИЧЕСКИ создадутся и рабочая кукла шмота, и пуленепробиваемый инвентарь!        
        current_player = units_state.add(M.PLAYER_UID, {
            unit_id = "player_mage",
            name_key = "class_mage",
            is_player = true,
            level = 1,
            experience = 0,
            type = "humanoid",
            rank = "common",
            loot_table_id = "empty",
            ai_profile = "none",
            base_aggro_range = 0,
            faction = "neutral_humanoid",
            -- Выставляем ХП и Ману, а units_state.add() сам шёлково упакует их в паспорт!
            health = 100,
            max_health = 100,
            resource = {
                type = "mana",
                current = 50,
                max = 50
            },
            speed = 220,
            hitbox_size = 64,
            saved_position = vmath.vector3(1126, 725, 1.0), -- Твоя стартовая точка Meadows
            base_stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 },
            action_bars = {
                [1] = {
                    [1] = { action_type = "ability", action_id = "melee_attack" },
                    [2] = { action_type = "ability", action_id = "frostbolt", triggers_gcd = true },
                    [3] = { action_type = "item",    action_id = "lesser_mana_potion", triggers_gcd = true },
                    [4] = { action_type = "item",    action_id = "iron_sword" },
                },
                [2] = {},
                [3] = {}
            }
        })
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



