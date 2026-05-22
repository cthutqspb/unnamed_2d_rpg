local M = {}

M.registry = {}

function M.init(id, data)
    -- Превращаем хеш в строку, чтобы Lua не ругался, а sys.save работал
    local key = tostring(id)
    M.registry[key] = data
end

function M.get(id)
    local key = tostring(id)
    return M.registry[key]
end

function M.remove(id)
    local key = tostring(id)
    M.registry[key] = nil
end

function M.clear()
    M.registry = {}
end

-- Для сохранения: просто отдаем всю таблицу
function M.get_all()
    return M.registry
end

-- Для загрузки: аккуратно обновляем только те данные, которые реально записаны в файле
function M.restore_all(data)
    -- Если из файла прилетела пустая таблица или nil, вообще ничего не трогаем,
    -- пусть в мире остается дефолтный стартовый лут!
    if not data then return end

    -- Бежим циклом только по сохраненным сундукам и обновляем их в реестре
    for container_id, container_data in pairs(data) do
        M.registry[container_id] = container_data
    end
end

return M

