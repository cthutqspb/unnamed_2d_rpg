local M = {}

M.registry = {} -- Назовем так для ясности

function M.init(id, data)
    M.registry[id] = data
end

function M.get(id)
    return M.registry[id]
end

function M.remove(id)
    M.registry[id] = nil
end

function M.clear()
    M.registry = {}
end

-- Для сохранения: просто отдаем всю таблицу
function M.get_all()
    return M.registry
end

-- Для загрузки: заменяем текущую таблицу той, что пришла из файла
function M.restore_all(data)
    M.registry = data or {}
end

return M
