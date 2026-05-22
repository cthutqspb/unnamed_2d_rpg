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
function M.get_actions(object_type, item_type, flags)
    flags = flags or {} -- защита от nil
    local result = {}
    
    if object_type == "item" and item_type then
        local specific = M.data[item_type] or {}
        
        for _, action in ipairs(specific) do
            local final_action = action
            
            -- ЗАМЕНА: Экипировать -> Снять
            if flags.is_equipped and action.event == "equip_item" then
                final_action = { name_key = "menu_unequip", event = "unequip_item" }
            end
            
            table.insert(result, final_action)
        end
        
        -- СПЛИТ: только в сумке и если стакается
        if flags.can_split and not flags.is_equipped then
            table.insert(result, { name_key = "menu_split", event = "request_split" })
        end

        -- ОБЩИЕ ДЕЙСТВИЯ
        for _, v in ipairs(SHARED_ITEM_ACTIONS) do 
            -- Скрываем "Выбросить", если вещь надета
            if not (flags.is_equipped and v.event == "drop_item") then
                table.insert(result, v) 
            end
        end
    else
        result = M.data[object_type] or M.data["default"]
    end
    
    return result
end

return M
