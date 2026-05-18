local strings = require("main.modules.data.strings")
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
        max_stack = 1
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
        max_stack = 1
    },
    ["leather_helmet"] = {
        name_key = "item_leather_helmet_name",
        animation = "leather_helmet",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2345,
        texture = "items_project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        weight = 1.0,
        stackable = false,
        max_stack = 1,
        stats = {
            stamina = 5,
            agility = 2
        }
    },
    ["clown_hat"] = {
        name_key = "item_clown_hat_name",
        animation = "clown_hat",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2347,
        texture = "items_project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        weight = 1.0,
        stackable = false,
        max_stack = 1,
        stats = {
            stamina = -2,
            agility = 3,
            intellect = 5
        }
    },
    ["lesser_mana_potion"] = {
        name_key = "item_lesser_mana_potion_name",
        desc_key = "item_lesser_mana_potion_desk",
        animation = "lesser_mana_potion",
        type = "POTION",
        tile_index = 2683,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno",
        stackable = true,
        max_stack = 20
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
    local item = items_by_hash[id] or M.items_raw[id]

    if item then
        item.name = strings.get(item.name_key)
        item.description = strings.get(item.desc_key)
        item.icon = tostring(item.tile_index)
    end
    return item
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
