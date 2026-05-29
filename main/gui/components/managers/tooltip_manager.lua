---@class TooltipSessionData
---@field type string Конкретный тип данных для выбора шаблона рендера
---@field info table Чистые Lua-данные (таблица предмета, конфиг спелла, стейт кабана)
---@field context string|table|nil 🚩 ФИКС ТИПОВ №1: Разрешаем хранить таблицу метаданных в сессии!

---@class TooltipManager
---@field TYPE_GUI_ITEM string Предметы инвентаря, куклы и сундуков ("gui_item")
---@field TYPE_GUI_SPELL string Заклинания и способности на панели скиллов ("gui_spell")
---@field TYPE_GUI_STAT string Характеристики в окне персонажа ("gui_stat")
---@field TYPE_WORLD_UNIT string Живые существа в мире: кабаны, росянки, NPC ("world_unit")
---@field TYPE_WORLD_PROP string Интерактивные объекты мира: сундуки, рычаги, двери ("world_prop")
---@field mouse_x number Текущая координата мыши X на экране
---@field mouse_y number Текущая координата мыши Y на экране
local M = {}

-- АТОМАРНЫЕ ТИПЫ ДАННЫХ ДЛЯ ШАБЛОНОВ ТУЛТИПОВ
M.TYPE_GUI_ITEM       = "gui_item"
M.TYPE_GUI_SPELL      = "gui_spell"
M.TYPE_GUI_STAT       = "gui_stat"
M.TYPE_WORLD_UNIT     = "world_unit"
M.TYPE_WORLD_PROP     = "world_prop"

M.mouse_x = 0
M.mouse_y = 0

---@type TooltipSessionData|nil
local current_data = nil

---Открыть сессию тултипа и сохранить данные ховера для слоя отображения (View)
---@param type string Строковый тип данных (используй константы M.TYPE_...)
---@param info table Чистая Lua-таблица состояния или статического конфига объекта
---@param context string|table|nil 🚩 ФИКС ТИПОВ №2: Синхронизируем типы с @field!
function M.show(type, info, context)
    current_data = {
        type = type,
        info = info,
        context = context
    }
end

---Закрыть сессию тултипа и очистить данные ховера
function M.hide()
    if current_data == nil then return end
    current_data = nil
end

---Получить полную структуру данных активной сессии тултипа
---@return TooltipSessionData|nil
function M.get_current()
    return current_data
end

---Получить точный строковый тип активного тултипа для выбора рендерера
---@return string|nil
function M.get_current_type()
    return current_data and current_data.type
end

---Обновить экранные координаты мыши для плавного следования тултипа за курсором
---@param x number|nil
---@param y number|nil
function M.update_mouse(x, y)
    M.mouse_x = x or M.mouse_x or 0
    M.mouse_y = y or M.mouse_y or 0
end

return M

