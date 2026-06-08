local interaction = require("main.modules.interaction")

---@class WorldItemData
---@field item_id string|nil Строковый ID предмета из items_db
---@field pos {x: number, y: number} Координаты предмета на игровой карте
---@field amount number Количество предметов в кучке на земле
---@field is_dynamic boolean Флаг: выброшен игроком (true) или лежал изначально на карте (false)
---@field is_collected boolean|nil
---@field zone_id string|nil Паспорт локации ("overworld" для материка, "necropolis" для данжей)

---@class WorldItemsState
---@field registry table<string, WorldItemData> Глобальный реестр ВСЕХ живых лут-объектов в мире
---@field is_loaded_from_save boolean Флаг: загружена ли игра из сохранения
---@field instances table<hash, string> Быстрый маппинг для рейкаста [go_id(hash)] = строка_uid
local M = {}

M.registry = {}
M.is_loaded_from_save = false
M.instances = {}

---Связать физический Game Object в мире с его уникальным строковым UID (Канон Скелетов)
---@param go_id hash Движковый хэш объекта
---@param uid string Чистая строковая переменная UID
function M.register(go_id, uid)
    -- Записываем хэш ключом, а чистую строку значением! Никаких тупых регулярок!
    M.instances[go_id] = uid
end

---Разорвать связь между физическим объектом и реестром инстансов
---@param go_id hash
function M.unregister(go_id)
    M.instances[go_id] = nil
end

---Добавить новый предмет в глобальный реестр (Для динамического дропа из инвентаря)
---@param item_id string Строковый ID типа предмета
---@param pos vector3 Мировые координаты спавна
---@param amount number Количество
---@param is_dynamic boolean Выброшен ли игроком вручную
---@param existing_uid string|nil Опциональный UID
---@param zone_id string|nil Опциональный паспорт зоны (дефолт: "overworld")
---@return string uid Генерируемый строковый UID предмета
function M.add(item_id, pos, amount, is_dynamic, existing_uid, zone_id)
    local salt = math.random(1000, 9999)

    -- 🎯 ТИТАНОВЫЙ СИ-ФИКС ТИПОВ:
    -- Мы принудительно прогоняем прилетевший из рюкзака хэш item_id через to_str!
    -- Из hash("crystal_sword") получится чистая Lua-строка "crystal_sword".
    -- Мутантские префиксы "hash: [...]" уничтожены во всей вселенной бэкенда!
    local s_item_id = interaction.clean_id(item_id) or "unknown"

    -- Собираем UID из КРИСТАЛЬНО ЧИСТОЙ строки s_item_id!
    local uid = existing_uid or string.format("%s_%d_%d", s_item_id, os.time(), salt)

    M.registry[uid] = {
        item_id = s_item_id, -- 🦾 Записываем чистую строку "crystal_sword"!
        pos = { x = pos.x, y = pos.y },
        amount = amount or 1,
        is_dynamic = (is_dynamic == true),
        is_collected = false,
        -- 🎯 СИ-ЗАМОК ДЛЯ ДАНЖЕЙ (WoW-канон):
        -- Если зона не передана, вещь канонично падает в Большой Открытый Мир ("overworld").
        -- Когда сделаешь пещеру, world.script будет передавать сюда "necropolis"!
        zone_id = zone_id or "overworld"
    }

    return uid
end

---Проверить, существует ли Душа предмета в глобальной памяти бэкенда (Для спавнера)
---@param uid string Чистая строка UID
---@return boolean
function M.exists(uid)
    -- Прямой, моментальный поиск по хэш-мапе за 1 Си-такт процессора!
    return M.registry[uid] ~= nil
end

---Получить полную структуру данных предмета по его строковому UID
---@param uid string
---@return table|nil
function M.get_item_by_uid(uid)
    return M.registry[uid]
end

---Пометить предмет на земле как собранный (WoW/BG3 канон)
---@param uid string Чистая строка UID
function M.remove(uid)
    if M.registry and M.registry[uid] then
        -- 🎯 ФИКС: Душа вечно живет в памяти, но получает метку сбора!
        M.registry[uid].is_collected = true
        print("💾 БЭКЕНД: Душа предмета [" .. uid .. "] запечатана флагом is_collected!")
    else
        print("🚨 БЭКЕНД: Ошибка удаления! Ключ [" .. tostring(uid) .. "] не найден в registry!")
    end
end

---Дополнительный быстрый метод-вопрос для скриптов
---@param uid string
---@return boolean
function M.is_item_collected(uid)
    if M.registry and M.registry[uid] then
        return M.registry[uid].is_collected == true
    end
    return false
end

function M.clear()
    M.registry = {}
    M.is_loaded_from_save = false
    M.instances = {}
end

function M.get_all()
    return M.registry
end

function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true
end

return M

