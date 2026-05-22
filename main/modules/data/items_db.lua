local locales = require("main.modules.data.locales.locale_manager")
local M = {}

M.items_raw = {
    ["iron_sword"] = {
        name_key = "item_iron_sword_name",
        desc_key = "item_iron_sword_desc",
        animation = "iron_sword",
        tile_index = 2976,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno",
        type = "weapon",
        equip_slot = "MAIN_HAND",
        stackable = false,
        max_stack = 1,
        quality = "common",
        weapon_type = "one_hand_sword",
        required = {
            level = 1,
            strength = 6
        },
        stats = {
            strength = 3
        },
        damage = {
            min = 3,
            max = 7,
            type = "physical"
        },
        price = 25,
        weight = 2.4

        -- scale = 0.5,
        -- drop_distance = 20,    -- на сколько пикселей перед игроком
        -- rotation = 0,          -- угол поворота на земле
    },
    ["crystal_sword"] = {
        name_key = "item_crystal_sword_name",
        desc_key = "item_crystal_sword_desc",
        animation = "crystal_sword",
        tile_index = 3013,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno",
        type = "weapon",
        equip_slot = "MAIN_HAND",
        stackable = false,
        max_stack = 1,
        quality = "rare",
        weapon_type = "one_hand_sword",
        required = {
            level = 3,
            intellect = 10
        },
        stats = {
            strength = 3,
            intellect = 2
        },
        effects = {
            { id = "mana_leech_on_hit", value = 1.0, chance = 100 }
        },
        use_effects = {
            {
                id = "restore_mana",
                value = { min = 10, max = 10},
                cooldown = 300
            }
        },
        damage = {
            min = 4,
            max = 8,
            type = "physical"
        },
        bonus_damage = {
            {
                min = 2,
                max = 3,
                type = "arcane"
            }
        },
        resists = {
            arcane = 15
        },
        price = 75,
        weight = 2.4
    },
    ["leather_helmet"] = {
        name_key = "item_leather_helmet_name",
        desc_key = "item_leather_helmet_desc",
        animation = "leather_helmet",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2345,
        texture = "items_project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        stackable = false,
        max_stack = 1,
        quality = "common",
        armor_type = "leather",
        required = {
            level = 2,
        },
        stats = {
            stamina = 5,
            agility = 2
        },
        effects = {
            { id = "increase_max_health", value = 20 }
        },
        armor_rating = 27,
        price = 15,
        weight = 1.0,
    },
    ["clown_hat"] = {
        name_key = "item_clown_hat_name",
        desc_key = "item_clown_hat_desc",
        animation = "clown_hat",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2347,
        texture = "items_project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        stackable = false,
        max_stack = 1,
        quality = "uncommon",
        armor_type = "leather",
        required = {
            level = 2,
            agility = 12,
            intellect = 8
        },
        stats = {
            stamina = -2,
            agility = 3,
            intellect = 5
        },
        effects = {
            { id = "chance_to_critical_hit", value = 2.5 }
        },
        armor_rating = 15,
        price = 40,
        weight = 1.2
    },
    ["lesser_mana_potion"] = {
        name_key = "item_lesser_mana_potion_name",
        desc_key = "item_lesser_mana_potion_desc",
        animation = "lesser_mana_potion",
        type = "potion",
        tile_index = 2683,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno",
        stackable = true,
        max_stack = 20,
        quality = "common",
        required = {
            level = 1,
            resource = "mana"
        },
        use_effects = {
            {
                id = "restore_mana",
                value = {min = 20, max = 40},
                cooldown = 1
            }
        },
        price = 5,
        weight = 0.1 -- нужно учитывать при стаках
    }
    -- ... остальные предметы
}

-- 2. Создаем вспомогательную таблицу, где ключами будут ХЕШИ
local items_by_hash = {}
for id_str, data in pairs(M.items_raw) do
    items_by_hash[hash(id_str)] = data
end

-- 3. Универсальная функция получения предмета
function M.get_item(id)
    -- Если id — это хеш (из go.property), берем из таблицы хешей
    -- Если id — это строка, берем из основной таблицы
    return items_by_hash[id] or M.items_raw[id]
end

function M.get_save_data()
    -- Просто возвращаем таблицу. sys.save отлично сохранит строки и числа.
    return M.items
end

function M.load_save_data(data)
    -- Заменяем текущие предметы загруженными
    M.items = data or {}
end

-- Не забудь функцию очистки для "Новой игры"
function M.clear()
    M.items = {}
    -- Если у тебя фиксированный размер, можно заполнить пустышками:
    -- for i=1, 24 do M.items[i] = {item_id = nil, amount = 0} end
end

return M
