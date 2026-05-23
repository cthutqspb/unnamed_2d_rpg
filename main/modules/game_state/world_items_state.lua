local M = {}

M.registry = {}       -- Динамика
M.static_configs = {} -- Статика
M.instances = {}      -- Маппинг

local function to_key(id)
    if not id then return nil end
    return type(id) == "userdata" and tostring(id) or id
end

function M.register(id, uid)
    M.instances[id] = to_key(uid)
end

function M.unregister(id)
    if M.instances then M.instances[id] = nil end
end

function M.register_static_config(uid, config)
    M.static_configs[to_key(uid)] = config
end

function M.get_item_by_uid(uid)
    local key = to_key(uid)
    return M.registry[key] or M.static_configs[key]
end

function M.add(item_id, pos, amount)
    local salt = math.random(1000, 9999)
    -- UID создаем как СТРОКУ
    local uid = string.format("%s_%d_%d", tostring(item_id), os.time(), salt)

    M.registry[uid] = {
        item_id = item_id,
        pos = { x = pos.x, y = pos.y },
        amount = amount or 1
    }
    return uid
end

function M.remove(uid)
    -- Используем to_key, чтобы точно попасть в нужную строку в registry
    local key = type(uid) == "userdata" and tostring(uid) or uid
    M.registry[key] = nil
    print("REMOVED FROM STATE:", key)
end


function M.clear()
    M.registry = {}
end

function M.get_all() return M.registry end
function M.restore_all(data) M.registry = data or {} end

return M


