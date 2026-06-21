---@class AbilityRequiredStats
---@field level number|nil
---@field class string|nil

---@class AbilityDamageConfig
---@field min number Минимальный урон
---@field max number Максимальный урон
---@field type string Тип урона ("physical", "magic")


---@class AbiltityConfig
---@field action_type string
---@field name_key string
---@field desc_key string
---@field texture string
---@field animation string
---@field title_index number
---@field range number
---@field cooldown number
---@field required AbilityRequiredStats
---@field damage AbilityDamageConfig
---@field effect string
---@field is_off_gcd boolean
local M = {}

M.abilites_raw = {
    ["melee_attack"] = {
        action_type = "ability",
        name_key = "melee_attack_name",
        desc_key = "melee_attack_desc",
        texture = "project_utumno",
        animation = "melee_attack",
        title_index = 3266,
        range = 0,                     -- дистанция удара посохом (в пикселях)
        cooldown = 1.5,         -- скорость атаки (раз в 1.5 секунды)
        required = {
          level = 1,
          class = "all"
        },
        damage = {
            min = 2,
            max = 4
        },
        effect = "none",
        is_off_gcd = true               -- ВАЖНО: автоатака не запускает ГКД магии!
    },
    ["frostbolt"] = {
        action_type = "ability",
        name_key = "frostbolt_name",
        desc_key = "frostbolt_desc",
        texture = "project_utumno",
        animation = "frostbolt",
        tile_index = 1650,
        range = 350,
        cooldown = 0, -- нет КД, но будет время каста
        required = {
            level = 1,
            class = "mage"
        },
        damage = {
            min = 9,
            max = 15
        },
        effect = "freeze",
        is_off_gcd = false              -- магия запускает ГКД!
    }
}

-- Быстрый кэш хэшированных ключей для мгновенного поиска из голых свойств Defold (go.property)
---@type table<hash, AbiltityConfig>
local abilities_by_hash = {}

for id_str, data in pairs(M.abilites_raw) do
    data.id = id_str
    abilities_by_hash[hash(id_str)] = data
end

---@param id any
---@return AbiltityConfig|nil data
function M.get_ability(id)
    return abilities_by_hash[id] or M.abilites_raw[id]
end

return M
