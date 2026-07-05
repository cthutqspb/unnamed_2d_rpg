---Универсальный Си-системный хелпер глубокого клонирования таблиц (WoW/BG3 канон)
local M = {}

---@param orig table Исходная таблица, которую нужно склонировать
---@return table copy Абсолютно независимый зеркальный слепок со своими хэш-адресами в RAM
function M.deepcopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            -- Рекурсивно клонируем ключи и значения, если внутри есть вложенные таблицы
            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
        end
        -- Копируем метатаблицу (если она была у исходного объекта)
        setmetatable(copy, M.deepcopy(getmetatable(orig)))
    else
        -- Если это число, строка или булеан — просто возвращаем значение
        copy = orig
    end

    return copy
end

return M
