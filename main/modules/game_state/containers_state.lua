local M = {}

M.registry = {}       -- Динамика: предметы, статус "лутался/нет" (для сейва)
M.static_configs = {} -- Статика: размеры, имена, типы (НЕ для сейва)
M.instances = {}      -- Связи: go_id -> uid (для рейкаста)

local function to_key(id)
    return type(id) == "userdata" and tostring(id) or id
end

-- Регистрация физического тела в мире
function M.register(id, uid)
    M.instances[id] = to_key(uid)
end

function M.unregister(id)
    M.instances[id] = nil
end

-- Регистрация "Чертежа" (вызываем в init)
function M.register_static_config(uid, config)
    M.static_configs[to_key(uid)] = config
end

-- Инициализация динамики (вызываем при лутании или загрузке)
function M.init(uid, data)
    M.registry[to_key(uid)] = data
end

-- УМНЫЙ ГЕТТЕР
function M.get(uid)
    local key = to_key(uid)
    -- Если сундук уже лутали, берем из реестра. 
    -- Если нет — отдаем его статический "чертеж".
    return M.registry[key] or M.static_configs[key]
end

function M.clear()
    -- При новой игре стираем только прогресс лутания
    M.registry = {}
    -- Статику и инстансы не трогаем, они привязаны к текущей сцене!
end

function M.get_all() return M.registry end

function M.restore_all(data)
    if not data then return end
    M.registry = data
end

return M

