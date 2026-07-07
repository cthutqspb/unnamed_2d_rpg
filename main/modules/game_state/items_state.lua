local interactions = require("main.modules.interactions")

---@class ItemInstance : ItemConfig       🚀 НАСЛЕДУЕМ ВСЮ СТАТИКУ (identity, visuals, properties) ИЗ ITEMS_DB!
---@field go_id hash                      Идентификатор игрового объекта на сцене Defold
---@field uid string                      Уникальный строковый UID конкретной кучки лута на полу ("i_1200_340")
---@field item_id string                  Строковый ID вещи из базы данных items_db ("crystal_sword")
---@field amount number                   Количество предметов в этой кучке (например, 10 банок маны)
---@field saved_position vector3          Честные Си-координаты vector3 лежащего лута со сцены
---@field is_dynamic boolean              Флаг: выброшен игроком на ходу (true) или лежал изначально на карте (false)
---@field is_collected boolean            Флаг: подобрал ли уже игрок этот лут с пола
---@field zone_id string                  Паспорт локации ("overworld" для материка, "necropolis" для данжей)
---@field items table|nil                 Для сундуков/бочек: массив лежащих внутри плоских предметов
---@field is_looted boolean               Для сундуков/бочек: статус генерации/обыска лута
---@field loot_table_id string            🚀 ТЕПЕРЬ ПОЛЕ ОФИЦИАЛЬНО НА КОРНЕ! ВАРНИНГ ИНЖЕКТА СТЕРТ!
---@field source_type "player"|"unit"|"object" Системная категория происхождения лута в RAM
---@field source_uid string                Уникальный UID конкретного дроппера ("player", "c_4385_3097")
---@field source_unit_id string|nil        Для трупов мобов: ID вида из базы ("skeleton_mage")

---@class ItemsState
---@field registry table<string, ItemInstance> Глобальный реестр ВСЕХ живых лут-объектов в мире Meadows
---@field instances table<hash, string>   Быстрый маппинг для рейкаста [go_id(hash)] = строка_uid
---@field is_loaded_from_save boolean     Флаг: загружена ли вселенная из сохранения
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
---@return ItemInstance Паспорт созданного или существующего предмета
function M.add(uid, props)
    -- 🦾 АВТО-ГЕНЕРАЦИЯ ДЛЯ ДИНАМИЧЕСКОГО ДРОПА:
    if not uid or uid == "" or uid == hash("") then
        local salt = math.random(1000, 9999)
        local clean_item_id = interactions.clean_id(props.item_id) or "item"
        uid = string.format("%s_%d_%d", clean_item_id, os.time(), salt)
    end

    -- 🦾 УМНЫЙ ААА-КАМБЭК МАТРЁШЕК НА ЗЕМЛЮ:
    if M.registry and M.registry[uid] and M.registry[uid].is_collected then
        local existing = M.registry[uid]
        print("🌍 БЭКЕНД [WorldState]: Возврат матрешки на землю! Оживляем UID:", uid)

        existing.is_collected = false
        existing.saved_position = props.saved_position

        if props.items then existing.items = props.items end
        return existing
    end

    -- 🛡️ ЗЕРКАЛЬНЫЙ ГВАРД СЕЙВА:
    if M.registry and M.registry[uid] then
        print("🛡️ БЭКЕНД: Паспорт предмета уже существует в RAM. Защита спасла сейв от затирания для:", uid)
        return M.registry[uid]
    end

    local string_item_id = interactions.clean_id(props.item_id) or "unknown"
    local string_loot_table_id = interactions.clean_id(props.loot_table_id) or "empty"
    local chunk_zone_id = props.zone_id or interactions.get_current_defold_chunk() or "overworld"

    -- 🚀 СТРОИТЕЛЬНЫЕ ЛЕСА КОНСТРУКТОРА (ИСПРАВЛЕНО):
    -- unit_instance на тактовое время сборки называется unit_instance, 
    -- а здесь — item_instance! Полная симметрия и защита глаз от каши полей!
    local item_instance = {
        item_id       = string_item_id,
        uid           = uid,
        amount        = props.amount or 1,
        is_dynamic    = (props.is_dynamic == true),
        is_collected  = false,
        loot_table_id = string_loot_table_id,
        zone_id       = chunk_zone_id,
        saved_position = props.saved_position,

        items         = props.items or nil,
        is_looted     = (props.is_looted == true)
    }

    M.registry[uid] = item_instance
    return item_instance
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
    print("--- 📥 [items_state] РЕСТАВРАЦИЯ ПРЕДМЕТОВ ИЗ СЕЙВА ---")
    -- 🎯 РЕГЕНЕРАЦИЯ ВЕКТОРОВ ПРЕДМЕТОВ ПРИ ЗАГРУЗКЕ СЕЙВА (Канон существ!):
    for uid, item in pairs(M.registry) do
        local saved_position = item.saved_position
        if saved_position and type(saved_position) == "table" then
            -- Превращаем плоскую таблицу JSON обратно в честный Си-вектор Defold!
            item.saved_position = vmath.vector3(saved_position.x, saved_position.y, saved_position.z or 1.0)
        end
        -- Принт покажет точные строки-ключи из JSON
        print(string.format("  KEY В СЕЙВЕ: [%s] | ITEM_ID: [%s] | ПОЗИЦИЯ: X=%s, Y=%s",
            tostring(uid), tostring(item.item_id), tostring(item.saved_position.x), tostring(item.saved_position.y)))
    end
end

return M

