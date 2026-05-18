local M = {}

-- Таблица соответствия типов объектов и доступных кнопок
local SHARED_ITEM_ACTIONS = {
    { name_key = "menu_drop",    event = "drop_item" },
    { name_key = "menu_examine", event = "examine_object" },
}

M.data = {
    ["weapon"] = {
        { name_key = "menu_equip",   event = "equip_item" },
        { name_key = "menu_repair",  event = "repair_item" },
        { name_key = "menu_sharpen", event = "sharpen_weapon" },
    },
    ["armor"] = {
        { name_key = "menu_equip",   event = "equip_item" },
        { name_key = "menu_repair",  event = "repair_item" },
    },
    ["scroll"] = {
        { name_key = "menu_use",     event = "use_item" },
        { name_key = "menu_learn",   event = "learn_spell" },
    },
    ["container"] = {
        { name_key = "menu_open",    event = "open_container" },
    }    
}

-- Умная функция сборки списка
-- context_menu_db.lua

function M.get_actions(object_type, item_type, is_stackable)
    local result = {}
    
    -- 1. Специфика типа (weapon, armor...)
    if object_type == "item" and item_type then
        local specific = M.data[item_type] or {}
        for _, v in ipairs(specific) do table.insert(result, v) end
        
        -- 2. Добавляем Сплит, если предмет стакается (больше 1 в пачке)
        if is_stackable then
            table.insert(result, { name_key = "menu_split", event = "request_split" })
        end

        -- 3. Общие действия (Выбросить/Осмотреть)
        for _, v in ipairs(SHARED_ITEM_ACTIONS) do table.insert(result, v) end
    else
        -- Для других типов (сундуки и т.д.)
        result = M.data[object_type] or M.data["default"]
    end
    
    return result
end

return M
