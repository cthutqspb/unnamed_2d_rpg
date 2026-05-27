local interaction = require("main.modules.interaction")

---@class WorldItemData
---@field item_id string|nil Строковый ID предмета из items_db
---@field pos {x: number, y: number} Координаты предмета на игровой карте
---@field amount number Количество предметов в кучке на земле
---@field is_dynamic boolean Флаг: выброшен игроком (true) или лежал изначально на карте (false)

---@class WorldItemsState
---@field registry table<string, WorldItemData> Глобальный реестр ВСЕХ живых лут-объектов в мире
---@field is_loaded_from_save boolean Флаг: загружена ли игра из сохранения
---@field instances table<hash, string> Быстрый маппинг для рейкаста [go_id(hash)] = строка_uid
local M = {}

M.registry = {}
M.is_loaded_from_save = false
M.instances = {}

---Вспомогательная функция-чистильщик: преобразует hash("item") или url в чистую строку
---@private
---@param id any Произвольный идентификатор (строка, хеш или url)
---@return string|nil Чистая строка или nil, если аргумент пустой
local function to_str(id)
    if not id then return nil end
    local s = tostring(id)
    -- Регулярка вырезает текст, находящийся внутри квадратных скобок [ ]
    return s:match("%[(.+)%]") or s
end

---Связать физический Game Object в мире с его уникальным строковым UID.
---@param id hash Идентификатор игрового объекта (go.get_id())
---@param uid string|hash Уникальный идентификатор предмета в реестре данных
function M.register(id, uid)
    M.instances[id] = to_str(uid)
end

---Разорвать связь между физическим объектом и реестром
---@param id hash Идентификатор уничтожаемого игрового объекта (go.get_id())
function M.unregister(id)
    -- Убрали лишний if, так как таблица гарантированно существует
    M.instances[id] = nil
end

---Добавить новый предмет в глобальный реестр предметов, лежащих на земле.
---@param item_id string|hash Строковый ID типа предмета
---@param pos vector3|table Мировые координаты спавна
---@param amount number|nil Количество (дефолт: 1)
---@param is_dynamic boolean|nil Выброшен ли игроком вручную из сумки
---@param existing_uid string|nil Опциональный UID
---@return string uid Сгенерированный или переданный уникальный строковый UID предмета
function M.add(item_id, pos, amount, is_dynamic, existing_uid)
    local salt = math.random(1000, 9999)
    local s_item_id = to_str(item_id)

    -- Если существующий UID не передан, собираем уникальную строку: "id_время_соль"
    local uid = existing_uid or string.format("%s_%d_%d", s_item_id or "unknown", os.time(), salt)

    M.registry[uid] = {
        item_id = s_item_id,
        pos = { x = pos.x, y = pos.y },
        amount = amount or 1,
        is_dynamic = (is_dynamic == true)
    }
    return uid
end

---Проверить, существует ли предмет с таким UID в глобальном реестре данных на земле
---@param uid string|hash Уникальный идентификатор предмета
---@return boolean @Возвращает true если предмет еще не подобрали и он записан в памяти
function M.exists(uid)
    local key = interaction.clean_id(uid)
    return M.registry[key] ~= nil
end

---Получить полную структуру данных предмета на земле по его UID
---@param uid string|hash Уникальный идентификатор предмета
---@return WorldItemData|nil Таблица с данными предмета или nil, если объект не найден
function M.get_item_by_uid(uid)
    return M.registry[to_str(uid)]
end

---Удалить предмет из реестра данных
---@param uid string|hash Уникальный идентификатор удаляемого предмета
function M.remove(uid)
    M.registry[to_str(uid)] = nil
end

---Полностью очистить состояние менеджера предметов
function M.clear()
    M.registry = {}
    M.is_loaded_from_save = false
end

---Получить весь глобальный реестр предметов на земле
---@return table<string, WorldItemData>
function M.get_all()
    return M.registry
end

---Восстановить состояние предметов из файла сохранения
---@param data table<string, WorldItemData> Таблица данных из сейва
function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true
end

return M

