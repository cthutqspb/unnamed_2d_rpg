---@class ContextMenuAction
---@field name_key string Ключ локализации для текста кнопки
---@field event string Системное имя события для отправки в GUI

---@class ContextMenuFlags
---@field is_equipped boolean|nil Надет ли предмет на куклу прямо сейчас
---@field can_split boolean|nil Можно ли разделить этот стак предметов

---@class ContextMenuDb
local M = {}

-- Действия, общие строго для ВСЕХ предметов в инвентаре
---@type ContextMenuAction[]
local SHARED_ITEM_ACTIONS = {
    { name_key = "menu_drop",    event = "item_drop" },
    -- Используем универсальный object_, так как осматривать можно и бочки в мире
    { name_key = "menu_examine", event = "object_examine" },
}

---@type table<string, ContextMenuAction[]>
M.data = {
    -- Inventory / GUI
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
    -- World
    ["container"] = {
        { name_key = "menu_open",    event = "container_open" },
        -- Бочку в мире тоже можно осмотреть через общее действие
        { name_key = "menu_examine", event = "object_examine" },
    },
    ["item_loot"] = {
        { name_key = "menu_pickup",  event = "item_pickup"},
        { name_key = "menu_examine", event = "object_examine" },
    },
    -- All
    ["default"] = {
        { name_key = "menu_examine", event = "object_examine" },
    }
}

---Собрать динамический список доступных действий для объекта
---@param object_type string Тип объекта ("item", "container", "npc")
---@param item_type string|nil Подтип предмета ("weapon", "armor", "scroll") если object_type == "item"
---@param flags ContextMenuFlags|nil Флаги состояния объекта
---@return ContextMenuAction[] Список сформированных кнопок для меню
function M.get_actions(object_type, item_type, flags)
    local f = flags or {}
    local result = {}

    -- 1. СЦЕНАРИЙ: Кликнули по предмету в инвентаре или на кукле
    if object_type == "item" and item_type then
        local specific = M.data[item_type] or {}

        for _, action in ipairs(specific) do
            local final_action = action

            -- ЗАМЕНА: Если вещь надета, меняем «Экипировать» на «Снять»
            -- Проверяем новое универсальное событие "item_transfer"
            if f.is_equipped and action.event == "item_transfer" then
                final_action = {
                    name_key = "menu_unequip",
                    event = "item_transfer",
                    from_paperdoll = true
                }
            end

            table.insert(result, final_action)
        end

        -- СПЛИТ: Разрешаем делить только в сумке, если стакается и вещь не надета
        if f.can_split and not f.is_equipped then
            table.insert(result, { name_key = "menu_split", event = "request_split" })
        end

        -- ОБЩИЕ ДЕЙСТВИЯ ПРЕДМЕТОВ
        for _, v in ipairs(SHARED_ITEM_ACTIONS) do
            -- 🚩 ИСПРАВЛЕНО: Скрываем «Выбросить» (item_drop), если вещь сейчас надета
            if not (f.is_equipped and v.event == "item_drop") then
                table.insert(result, v)
            end
        end

    -- 2. СЦЕНАРИЙ: Кликнули по объекту в мире (сундук, бочка, рычаг)
    else
        result = M.data[object_type] or M.data["default"]
    end

    return result
end

return M

