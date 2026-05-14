local M = {}

M.registry = {}

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

