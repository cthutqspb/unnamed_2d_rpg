local M = {}

M.db = {
    ["melee_attack"] = {
        name_key = "melee_attack_name",
        desc_key = "melee_attack_desc",
        texture = "project_utumno",
        animation = "melee_attack",
        title_index = "3266",
        range = 0,                     -- дистанция удара посохом (в пикселях)
        cooldown = 1.5,         -- скорость атаки (раз в 1.5 секунды)
        required = {
          level = 1,
          class = "all"
        },
        damage = {
            min = 0,
            max = 1
        },
        effect = "none",
        is_off_gcd = true               -- ВАЖНО: автоатака не запускает ГКД магии!
    },
    ["frostbolt"] = {
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

function M.get_ability(ability_id)
    return M.db[ability_id]
end

return M

