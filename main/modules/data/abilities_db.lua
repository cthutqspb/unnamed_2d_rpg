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

---@class AbilityConfig
---@field action_type string
---@field id string Уникальный строковый ID заклинания ("frostbolt")
---@field name_key string
---@field desc_key string
---@field texture string
---@field animation string
---@field title_index number
---@field projectile_id string|nil
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
        action_type = "ability",
        name_key = "melee_attack_name",
        desc_key = "melee_attack_desc",
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
        action_type = "ability",
        name_key = "frostbolt_name",
        desc_key = "frostbolt_desc",
        texture = "project_utumno",
        animation = "frostbolt",
        tile_index = 1650,
        projectile_id = "frostbolt_projectile",
        range = 350,
        cast_time = 2.5,
        cost = {
            resource = "mana",
            value = 4
        },
        cooldown = 0, -- нет КД, но будет время каста
        requires_target = true,
        required = {
            level = 1,
            class = "mage"
        },
        damage = {
            min = 9,
            max = 15,
            type = "frost",
            weapon_multiplier = 0.2,
            scaling_stats = { intellect = 1.0 }
        },
        effect = "freeze",
        triggers_gcd = true              -- магия запускает ГКД!
    }
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
