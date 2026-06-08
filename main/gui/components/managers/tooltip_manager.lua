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
M.WORLD_TYPES = {
    ["world_unit"] = "WORLD_UNIT", -- существа, NPC
    ["world_object"] = "WORLD_OBJECT", -- сундуки, двери, интеракты
    ["world_item"]   = "WORLD_ITEM", -- лут на земле (когда он в мире)
}

M.GUI_TYPES = {
    ["gui_item"]   = "GUI_ITEM",  -- шмотки в сумках/кукле
    ["gui_ability"]  = "GUI_ABILITY", -- спеллы на панелях
    ["gui_stat"]   = "GUI_STAT",  -- статы в окне персонажа
}

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

---Принудительно закрыть тултип, ЕСЛИ он принадлежит игровому миру
function M.hide_world_tooltips()
    if not current_data then return end

    -- Просто проверяем: есть ли тип текущего тултипа в словаре WORLD_TYPES?
    if M.WORLD_TYPES[current_data.type] then
        current_data = nil
    end
end

---Принудительно закрыть тултип, ЕСЛИ он принадлежит интерфейсу (GUI)
function M.hide_gui_tooltips()
    if not current_data then return end

    -- Просто проверяем: есть ли тип текущего тултипа в словаре GUI_TYPES?
    if M.GUI_TYPES[current_data.type] then
        current_data = nil
    end
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

