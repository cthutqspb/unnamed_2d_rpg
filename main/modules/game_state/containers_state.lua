local interaction = require("main.modules.interaction")
local M = {}

M.registry = {}       -- Динамика: прогресс лутания и шмот (Для сейва)
M.static_configs = {} -- Статика: базовые конфиги из редактора (НЕ для сейва)
M.instances = {}      -- Связи: go_id(hash) -> uid(string) ДЛЯ РЕЙКАСТА МЫШИ!

---Регистрация физического тела в мире (По канону Скелетов)
---@param id hash Сырой Си-адрес go.get_id() из мира
---@param uid string|hash Уникальный паспорт сундука
function M.register(id, uid)
    -- 🎯 ТИТАНОВЫЙ ААА-ЗАМОК: 
    -- Ключом оставляем голый Си-хэш id (userdata) для моментального рейкаста мыши!
    -- Значением пишем чистую Lua-строку uid через clean_id!
    if id then
        M.instances[id] = interaction.clean_id(uid) or ""
    end
end

---Разорвать связь инстанса при выгрузке
---@param id hash
function M.unregister(id)
    -- Ищем по сырому Си-хэшу напрямую
    if id then
        M.instances[id] = nil
    end
end

---Регистрация статического чертежа из редактора
---@param uid string|hash
---@param config table
function M.register_static_config(uid, config)
    local key = interaction.clean_id(uid)
    if key then
        M.static_configs[key] = config
    end
end

---Инициализация динамического состояния сундука
---@param uid string|hash
---@param data table
function M.init(uid, data)
    local key = interaction.clean_id(uid)
    if key then
        M.registry[key] = data
    end
end

---Умный ААА-геттер данных контейнера
---@param uid string|hash
---@return table|nil
function M.get(uid)
    local key = interaction.clean_id(uid)
    if not key then return nil end
    return M.registry[key] or M.static_configs[key]
end

function M.clear()
    -- При новой игре стираем только прогресс лутания
    M.registry = {}
    M.instances = {}
end

function M.get_all()
    return M.registry
end

function M.restore_all(data)
    if not data then return end
    M.registry = data
end

return M

