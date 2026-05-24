local M = {}

M.registry = {}
M.is_loaded_from_save = false -- Тот самый флаг
M.instances = {} -- Телефонная книга для рейкаста [id] = uid

-- Функция-чистильщик: превращает hash("item") в строку "item"
local function to_str(id)
    if not id then return nil end
    local s = tostring(id)
    return s:match("%[(.+)%]") or s
end

function M.register(id, uid)
    M.instances[id] = to_str(uid)
end

function M.add(item_id, pos, amount, is_dynamic, existing_uid)
    local salt = math.random(1000, 9999)
    -- Генерируем UID как чистую СТРОКУ
    local s_item_id = to_str(item_id)
    local uid = existing_uid or string.format("%s_%d_%d", s_item_id, os.time(), salt)

    M.registry[uid] = {
        item_id = s_item_id, -- пишем СТРОКУ
        pos = { x = pos.x, y = pos.y },
        amount = amount or 1,
        is_dynamic = (is_dynamic == true)
    }
    return uid
end

function M.exists(uid)
    -- Приводим входящий UID к чистой строке (убираем hash: [])
    local key = tostring(uid):match("%[(.+)%]") or tostring(uid)
    
    -- Если в реестре живых объектов есть такая запись — возвращаем true
    return M.registry[key] ~= nil
end


function M.get_item_by_uid(uid)
    return M.registry[to_str(uid)]
end

function M.remove(uid)
    M.registry[to_str(uid)] = nil
end

function M.clear()
    M.registry = {}
    M.is_loaded_from_save = false -- Сбрасываем при новой игре
end

function M.unregister(id)
    if M.instances then
        M.instances[id] = nil
    end
end

-- Системные
function M.get_all() return M.registry end

function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true -- Поднимаем при загрузке
end

return M

