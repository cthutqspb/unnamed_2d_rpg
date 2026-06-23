local interactions = require("main.modules.interactions")

---@class WorldItemInstanceData
---@field item_id string|nil Строковый ID предмета из items_db
---@field uid string
---@field saved_position {x: number, y: number, z: number} Координаты предмета на игровой карте
---@field amount number Количество предметов в кучке на земле
---@field is_dynamic boolean Флаг: выброшен игроком (true) или лежал изначально на карте (false)
---@field is_collected boolean|nil
---@field zone_id string|nil Паспорт локации ("overworld" для материка, "necropolis" для данжей)

---@class WorldItemsState
---@field registry table<string, WorldItemInstanceData> Глобальный реестр ВСЕХ живых лут-объектов в мире
---@field instances table<hash, string> Быстрый маппинг для рейкаста [go_id(hash)] = строка_uid
---@field is_loaded_from_save boolean Флаг: загружена ли игра из сохранения
local M = {}

M.registry = {}
M.instances = {}
M.is_loaded_from_save = false

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

---Добавить новый предмет в глобальный реестр (Умная WoW-фабрика)
---@param uid string Уникальный строковый UID предмета
---@param props table Параметры (item_id, saved_position, amount, is_dynamic, loot_table_id, zone_id, items, is_looted)
---@return table Паспорт созданного или существующего предмета
function M.add(uid, props)
    -- 🦾 АВТО-ГЕНЕРАЦИЯ ДЛЯ ДИНАМИЧЕСКОГО ДРОПА:
    -- Если контроллер не прислал готовый UID (лут с моба или выброс шмотки), 
    -- бэкенд сам собирает уникальный ключ с солью и временем, убирая лапшу из внешних скриптов!
    if not uid or uid == "" or uid == hash("") then
        local salt = math.random(1000, 9999)
        local clean_item_id = interactions.clean_id(props.item_id) or "item"
        uid = string.format("%s_%d_%d", clean_item_id, os.time(), salt)
    end

    -- 🛡️ ЗЕРКАЛЬНЫЙ ГВАРД СЕЙВА:
    if M.registry and M.registry[uid] then
        print("🛡️ БЭКЕНД: Паспорт предмета уже существует в RAM. Защита спасла сейв от затирания для:", uid)
        return M.registry[uid] -- Возвращает ТАБЛИЦУ, как у существ!
    end

    local string_item_id = interactions.clean_id(props.item_id) or "unknown"
    local string_loot_table_id = interactions.clean_id(props.loot_table_id) or "empty"
    local chunk_zone_id = props.zone_id or interactions.get_current_defold_chunk() or "overworld"

    ---@type table
    local instance_data = {
        item_id = string_item_id,
        uid = uid,
        amount = props.amount or 1,
        is_dynamic = (props.is_dynamic == true),
        is_collected = false,
        loot_table_id = string_loot_table_id,
        zone_id = chunk_zone_id,
        saved_position = props.saved_position,

        -- Сразу закладываем поддержку вложенных шмоток бочки/сундука и статус обыска
        items = props.items or nil,
        is_looted = (props.is_looted == true)
    }

    M.registry[uid] = instance_data
    return instance_data
end


---Обновить физические координаты предмета в реестре (Для стриминга чанков)
---@param uid string Уникальный строковый UID предмета
---@param position vector3 Новые мировые координаты из движка
function M.update_position(uid, position)
    if M.registry and M.registry[uid] then
        -- Намертво изолируем внутренности бэкенда. 
        -- Скрипт просто кидает вектор, а модуль сам раскладывает его на безопасные Lua-числа!
        M.registry[uid].saved_position = {
            x = position.x,
            y = position.y,
            z = position.z or 1.0
        }
    end
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
    print("--- 📥 [world_items_state] РЕСТАВРАЦИЯ ПРЕДМЕТОВ ИЗ СЕЙВА ---")
    -- 🎯 РЕГЕНЕРАЦИЯ ВЕКТОРОВ ПРЕДМЕТОВ ПРИ ЗАГРУЗКЕ СЕЙВА (Канон существ!):
    for uid, item_data in pairs(M.registry) do
        local saved_position = item_data.saved_position
        if saved_position and type(saved_position) == "table" then
            -- Превращаем плоскую таблицу JSON обратно в честный Си-вектор Defold!
            item_data.saved_position = vmath.vector3(saved_position.x, saved_position.y, saved_position.z or 1.0)
        end
        -- Принт покажет точные строки-ключи из JSON
        print(string.format("  KEY В СЕЙВЕ: [%s] | ITEM_ID: [%s] | ПОЗИЦИЯ: X=%s, Y=%s", 
            tostring(uid), tostring(item_data.item_id), tostring(item_data.saved_position.x), tostring(item_data.saved_position.y)))
    end
end

return M

