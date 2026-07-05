---@class AbilityRequiredStats
---@field level number|nil
---@field class string|nil

---@class AbilityCostConfig
---@field resource string Тип ресурса ("mana", "energy", "rage", "battery", "heat")
---@field value number Количество

---@class AbilityDamageConfig
---@field min number Минимальный урон
---@field max number Максимальный урон
---@field type string Тип урона ("physical", "magic")
---@field weapon_multiplier number|nil
---@field scaling_stats table<string, number>|nil 🦾 МУЛЬТИ-СТАТ СКЕЙЛИНГ: {intellect = 1.0, strength = 0.5}

---@class AbilitiFXConfig
---@field sprite_animation string|nil    -- Кадры летящего тела ("frostbolt_fly")
---@field particle_fx string|nil   -- Шлейф или луч ("lightning_beam")
---@field hit_fx string|nil        -- Взрыв при импакте ("frost_impact")
---@field duration number|nil -- Для лучше или еще чего мгновенного

---@class AbilityConfig
---@field tags string[]
---@field action_type string
---@field id string Уникальный строковый ID заклинания ("frostbolt")
---@field name_key string
---@field desc_key string
---@field texture string
---@field animation string
---@field title_index number
---@field delivery_type string|nil
---@field projectile_factory string
---@field fx AbilitiFXConfig|nil
---@field projectile_speed number|nil -- Для снарядов которые летят
---@field range number
---@field cast_time number|nil
---@field cooldown number
---@field cost AbilityCostConfig|nil
---@field requires_target boolean
---@field required AbilityRequiredStats
---@field damage AbilityDamageConfig
---@field effect string
---@field triggers_gcd boolean
local M = {}

M.abilites_raw = {
    ["melee_attack"] = {
        tags = {
            "melee_attack",
            "physical"
        },
        action_type = "ability",
        name_key = "ability_melee_attack_name",
        desc_key = "ability_melee_attack_desc",
        texture = "project_utumno",
        animation = "melee_attack",
        title_index = 3266,
        range = 12,                     -- дистанция удара посохом (в пикселях)
        cooldown = 1.5,         -- скорость атаки (раз в 1.5 секунды)
        requires_target = true,
        required = {
          level = 1,
          class = "all"
        },
        damage = {
            min = 2,
            max = 4,
            type = "physical",
            weapon_multiplier = 1.0,
            scaling_stats = { strength = 1.0 }
        },
        effect = "none",
        triggers_gcd = false              -- ВАЖНО: автоатака не запускает ГКД магии!
    },
    ["frostbolt"] = {
        tags = {
            "ranged_attack",
            "damage",
            "frost"
        },
        action_type = "ability",
        name_key = "ability_frostbolt_name",
        desc_key = "ability_frostbolt_desc",
        texture = "project_utumno",             -- Твой графический атлас/тайлсет
        animation = "frostbolt",                -- Твоя анимация каста (иконка/FX)
        tile_index = 1650,                      -- Твой Си-ИНН иконки в атласе для экшен-бара

        -- 🚀 1. ПАЙПЛАЙН ДОСТАВКИ И ФАБРИКА СНАРЯДА (0 ПЛОЖЕНИЯ ОБЪЕКТОВ):
        delivery_type = "projectile",           -- Маркер для комбат-менеджера: "Нужно спавнить пулю!"
        -- Нам больше НЕ НУЖНЫ 100 разных фабрик под каждый чих!
        -- На карте вешается ровно ОДНА универсальная фабрика, спавнящая слепой projectile.go!
        projectile_factory = "game_scene:/world_controller#projectile_factory",

        -- 🚀 2. ВИЗУАЛЬНЫЙ СИ-ПАСПОРТ СНАРЯДА (Для на лету-перекраса пули в рантайме):
        -- Слепая пуля родится на карте, заглянет сюда и сама сочно сменит шкуру!)
        fx = {
            sprite_animation = "frostbolt_sprite",      -- Имя флипбука летящей ледяной пули в project_utumno
            particle_fx = "frostbolt_trail",         -- Шлейф снежинок/парциклов сзади пули
            hit_fx      = "frostbolt_impact",        -- Вспышка осколков льда при ударе в хитбокс
            -- duration    = "0.4" -- Фростболту не нужна!
        },

        -- 🚀 3. ДИНАМИКА, ФИЗИКА И ТАРГЕТИНГ ПОЛЕТА:
        range = 450,                            -- Максимальная дистанция каста/полета в пикселях
        speed = 450,                            -- Скорость полета снаряда (пикселей в секунду)
        is_homing = true,                       -- 🎯 WoW-КАНОН: Пуля намертво доводится в круглый хитбокс цели!
        requires_target = true,                 -- Нужна ли живая цель в таргете мага для пуска
        required = {
            level = 1,
            class = "mage"
        },

        -- 🚀 4. ТAКТOВЫE И СРEДСТВEННЫE ТAЙМEРЫ RAM-РEEСТРA:
        cast_time = 1.5,                        -- Время сотворения (2.5 сек магу запрещено ходить!)
        cooldown = 0,                           -- Нет КД, заклинание лимитируется только временем каста
        triggers_gcd = true,                    -- Магия Meadows намертво запускает ГКД!
        cost = {
            resource = "mana",
            value = 4                           -- Стоимость каста в RAM-единицах
        },

        -- 🚀 5. МАТЕМАТИКА БЭКЕНД-ЯДРА ПРИ СТОЛКНОВЕНИИ (On-Hit Payload):
        -- Когда пуля врезается в круглый хитбокс врага, она слепо передает этот пакет в apply_damage!
        damage = {
            min = 9,
            max = 15,
            type = "frost",                     -- Стихия урона (для будущих резистов)
            weapon_multiplier = 0.2,            -- Скалирование от урона надетого посоха
            scaling_stats = { intellect = 1.0 } -- Скалирование от Интеллекта мага (1 Интеллект = +1 к дамагу)
        },
        effect = "freeze",                      -- Твой оригинальный триггер механики замедления
        on_hit_effects = {
            { type = "apply_debuff", id = "chilled_slow", duration = 4.0 } -- Задел под дебафф
        }
    },
    ["lightning_bolt"] = {
        tags = {
            "ranged_attack",
            "damage",
            "lightning"
        },
        action_type = "ability",
        name_key = "ability_lightning_bolt_key",
        desc_key = "ability_lightning_bolt_desc",
        texture = "project_utumno",
        animation = "lightning_bolt",
        title_index = "1862",
        delivery_type = "beam",
        projectile_factory = "game_scene:/world_controller#projectile_fx_factory",
        fx = {
            sprite_animation = "lightning_bolt_sprite",
            particle_fx = "lightning_beam",
            duration = 0.4
            -- hit_fx      = "lightning_bolt_impact",
        },
        range = 750,
        speed = 450,
        is_homing = true,
        requires_target = true,
        required = {
            level = 1,
            class = "mage"
        },
        cast_time = 1.7,
        cooldown = 0,
        triggers_gcd = true,
        cost = {
            resource = "mana",
            value = 7
        },
        damage = {
            min = 4,
            max = 20,
            type = "lightning",
            weapon_multiplier = 0.25,
            scaling_stats = { intellect = 1.0 }
        },
        effect = "electrifies",
        on_hit_effects = {
            -- добавить заряди дебафа, заодно ауры потестить
        }
    },
}

-- Быстрый кэш хэшированных ключей для мгновенного поиска из голых свойств Defold (go.property)
---@type table<hash, AbilityConfig>
local abilities_by_hash = {}

for id_str, data in pairs(M.abilites_raw) do
    data.id = id_str
    abilities_by_hash[hash(id_str)] = data
end

---@param id any
---@return AbilityConfig|nil data
function M.get_ability(id)
    return abilities_by_hash[id] or M.abilites_raw[id]
end

return M
