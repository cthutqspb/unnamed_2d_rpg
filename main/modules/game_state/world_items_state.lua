local M = {}

-- Таблица вида: [instance_id] = { item_id = "iron_sword", pos = vmath.vector3(...), amount = 1 }
M.registry = {}
local counter = 0 -- Для генерации уникальных ID предметов на земле

function M.add(item_id, pos, amount)
    -- Соль из времени + счетчик + id предмета
    local salt = math.random(1000, 9999)
    local uid = string.format("%s_%d_%d", item_id, os.time(), salt)

    M.registry[uid] = {
        item_id = item_id,
        pos = { x = pos.x, y = pos.y },
        amount = amount or 1
    }
    return uid
end

function M.remove(uid)
    M.registry[uid] = nil
end

function M.get_item_by_uid(uid)
    -- Если uid пустой или записи нет, вернет nil
    return M.registry[uid]
end

function M.get_all()
    return M.registry
end

function M.restore_all(data)
    M.registry = data or {}
    -- Восстанавливаем счетчик, чтобы ID не дублировались
    for uid in pairs(M.registry) do
        local num = tonumber(uid:match("item_(%d+)"))
        if num and num > counter then counter = num end
    end
end

function M.clear()
    M.registry = {}
    counter = 0
end

return M

