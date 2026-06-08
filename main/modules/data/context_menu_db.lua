local M = {}

-- Действия, общие строго для ВСЕХ предметов внутри инвентаря
local SHARED_ITEM_ACTIONS = {
    { name_key = "menu_drop",    event = "item_drop" },
    { name_key = "menu_examine", event = "object_examine" },
}

---@type table<string, ContextMenuAction[]>
M.data = {
    -- Внутренние типы рюкзака/куклы
    ["weapon"] = {
        { name_key = "menu_equip",   event = "item_transfer" },
        { name_key = "menu_repair",  event = "item_repair" },
        { name_key = "menu_sharpen", event = "item_sharpen" },
    },
    ["armor"] = {
        { name_key = "menu_equip",   event = "item_transfer" },
        { name_key = "menu_repair",  event = "item_repair" },
    },
    ["scroll"] = {
        { name_key = "menu_use",     event = "item_use" },
        { name_key = "menu_learn",   event = "item_learn" },
    },
    ["container"] = {
        { name_key = "menu_open",    event = "container_open" },
        { name_key = "menu_examine", event = "object_examine" },
    },

    -- Чистокровные атомарные типы для игрового мира Meadows (Никакой каши!)
    ["world_item"] = {
        { name_key = "menu_pickup",  event = "item_pickup" },
        { name_key = "menu_examine", event = "object_examine" },
    },
    ["world_object"] = {
        { name_key = "menu_open",    event = "container_open" },
        { name_key = "menu_examine", event = "object_examine" },
    },
    ["default"] = {
        { name_key = "menu_examine", event = "object_examine" },
    }
}

---Собрать динамический список доступных действий для объекта (БГ3/WoW-канон)
---@param object_type string Главный тип инспекции ("gui_item", "world_item", "world_object", "creature")
---@param item_cfg table|nil Конфиг из items_db (для существ nil)
---@param flags table|nil Флаги состояния (is_equipped, can_split)
---@param data table|nil Дополнительный пейлод (slot_index, source_url)
---@return ContextMenuAction[] Список сформированных кнопок для меню
function M.get_actions(object_type, item_cfg, flags, data)
    local f = flags or {}
    local d = data or {}
    local result = {}

    -- =========================================================================
    -- СЦЕНАРИЙ 1: ПРЕДМЕТЫ ВНУТРИ СУМОК И КУКЛЫ (Есть slot_index!)
    -- =========================================================================
    if d.slot_index ~= nil and item_cfg then
        local item_type = item_cfg.type or "default"
        local specific = M.data[item_type] or {}
        
        for _, action in ipairs(specific) do
            local final_action = action
            if f.is_equipped and action.event == "item_transfer" then
                final_action = {
                    name_key = "menu_unequip",
                    event = "item_transfer",
                    data = { from_paperdoll = true }
                }
            end
            table.insert(result, final_action)
        end

        if f.can_split and not f.is_equipped then
            table.insert(result, { name_key = "menu_split", event = "execute_split" })
        end

        for _, v in ipairs(SHARED_ITEM_ACTIONS) do
            if not (f.is_equipped and v.event == "item_drop") then
                -- Развод кнопок Лута/Продажи/Сброса по source_url
                local url_str = d.source_url and tostring(d.source_url) or ""
                if string.find(url_str, "container_window") and v.event == "item_drop" then
                    table.insert(result, { name_key = "menu_take", event = "item_transfer" })
                else
                    table.insert(result, v)
                end
            end
        end

    -- =========================================================================
    -- СЦЕНАРИЙ 2: ОБЪЕКТЫ И ПРЕДМЕТЫ В ОТКРЫТОМ МИРЕ MEADOWS (Слот равен nil)
    -- =========================================================================
    else
        -- Заливаем базовый, атомарный набор кнопок для текущего типа мира
        local base_actions = M.data[object_type] or M.data["default"]
        for _, action in ipairs(base_actions) do
            table.insert(result, action)
        end

        -- 🎯 ТВОЙ ГЕНИАЛЬНЫЙ ДИНАМИЧЕСКИЙ СИ-ФИКС (Прихуяриваем доп-кнопки на ходу):
        -- Если мы кликнули ПКМ по шмотке на земле, и её action_type в базе — "container_item",
        -- мы прямо посреди кадра динамически расширяем массив result нашими тремя кнопками!
        if object_type == "world_item" and item_cfg and item_cfg.action_type == "container_item" then
            
            -- Удаляем базовую кнопку "menu_pickup" (Подобрать), так как для бочки 
            -- нам нужна кастомная кнопка "Забрать коробку целиком"!
            for i = #result, 1, -1 do
                if result[i].event == "item_pickup" then
                    table.remove(result, i)
                end
            end

            -- Вставляем доп-кнопки строго НАВЕРХ меню перед кнопкой "Осмотреть"
            table.insert(result, 1, { name_key = "menu_open",     event = "container_open" })
            table.insert(result, 2, { name_key = "menu_lockpick", event = "container_lockpick" })
            table.insert(result, 3, { name_key = "menu_disarm",   event = "container_disarm" })
            table.insert(result, 4, { name_key = "menu_take_box", event = "item_pickup", data = { is_take_box_action = true } })
        end
    end

    return result
end

return M

