local game_state = require("main.modules.game_state.game_state")
local units_state = require("main.modules.game_state.units_state")

---@class CharacterDataModule
---@field player UnitInstance|table|nil Наш гибридный указатель-мост
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
            unit_id   = "player_mage",
            is_player = true,
            level     = 1,
            experience = 0,
            saved_position = vmath.vector3(1126, 725, 1.0),

            -- 🆔 1. МЕТАДАННЫЕ (identity)
            identity = {
                name_key   = "class_mage",
                race       = "human",
                faction    = "neutral_humanoid",
                type       = "humanoid",
                default_rank = "common",
                unit_class = { mage = true },
            },

            -- 🧬 2. ХАРАКТЕРИСТИКИ ДУШИ (attributes)
            attributes = {
                strength  = 10,
                agility   = 10,
                intellect = 10,
                stamina   = 10
            },

            -- 📊 3. ВТОРИЧНЫЕ БОЕВЫЕ ПАРАМЕТРЫ (parameters)
            parameters = {
                base_health   = 100,
                max_health    = 100,
                base_speed    = 220,
                current_speed = 220,
                hitbox_size   = 64,
                loot_table_id = "empty",
            },

            -- 🧪 4. МУТАБЕЛЬНЫЕ ЖИВЫЕ РЕСУРСЫ (resource и health_resource)
            health_resource = {
                current = 100,
                max     = 100
            },
            resource = {
                type    = "mana",
                current = 50,
                max     = 50
            },

            -- 🎨 5. ВИЗУАЛЫ
            visuals = {
                animation = "player_mage_idle",
                texture   = "project_utumno",
            },

            -- 🧠 6. ПАСПОРТ ИИ ДЛЯ ИГРОКА (Заглушка)
            ai = {
                profile = "none",
                base_aggro_radius = 0,
                is_ranged = true,
                flee_range = 0,
                tag_weights = {}
            },

            abilities = { "melee_attack", "frostbolt", "lightning_bolt" },

            action_bars = {
                [1] = {
                    [1] = { action_type = "ability", action_id = "melee_attack" },
                    [2] = { action_type = "ability", action_id = "frostbolt" },
                    [3] = { action_type = "ability", action_id = "lightning_bolt" },
                    [4] = { action_type = "item",    action_id = "lesser_mana_potion" },
                    [5] = { action_type = "item",    action_id = "iron_sword" },
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
    local player = M.player
    return (player and player.cast.gcd_current and player.cast.gcd_current > 0) or false
end

---Запустить ГКД для игрока на бэкенде
---@param duration number Время в секундах (1.5)
function M.start_gcd(duration)
    local player = M.player
    if player then
        player.cast.gcd_current = duration
    end
end

return M



