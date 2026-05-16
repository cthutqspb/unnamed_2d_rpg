local M = {}

-- Таблица соответствия типов объектов и доступных кнопок
M.data = {
    ["item"] = {
        { name_key = "menu_use",     event = "use_item" },
        { name_key = "menu_split",   event = "request_split" },
        { name_key = "menu_drop",    event = "drop_item" },
        { name_key = "menu_examine", event = "examine_object" },
    },
    ["container"] = {
        { name_key = "menu_open",    event = "open_container" },
        { name_key = "menu_examine", event = "examine_object" },
    },
    ["default"] = {
        { name_key = "menu_examine", event = "examine_object" },
    }
}

function M.get_actions(type)
    return M.data[type] or M.data["default"]
end

return M

