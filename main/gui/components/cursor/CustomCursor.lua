---@class CustomCursorModule
local M = {}

---@type string Текущий активный стиль флипбука в памяти
local current_style = "cursor_default"

---Сохранить желаемый стиль курсора в сессию менеджера
---@param style_name string Имя анимации из атласа ("cursor_red", "cursor_white", "cursor_arrow")
function M.set_style(style_name)
    -- Просто перезаписываем Lua-строку в памяти!
    current_style = style_name or "cursor_default"
end

---Сбросить стиль курсора в дефолтную стрелочку
function M.reset()
    current_style = "cursor_default"
end

---Получить текущий активный стиль для слоя отображения (View)
---@return string
function M.get_current_style()
    return current_style
end

return M


