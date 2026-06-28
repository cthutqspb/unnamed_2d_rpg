local world_items_state = require("main.modules.game_state.world_items_state")
local containers_state = require("main.modules.game_state.containers_state")
local units_state = require("main.modules.game_state.units_state")

---@class GameStateFacade
---@field get_uid_by_go_id function
---@field get_entity_by_uid function
---@field get_player_data function 
local M = {}

---Узнать тип объекта и получить его чистые данные по go_id из мира (из рейкаста)
---@param go_id hash Идентификатор игрового объекта из физического луча мыши
---@return string|nil kind Тип объекта ("world_object", "world_item", "unit")
---@return string|nil uid Уникальный строковый UID объекта в реестре состояний
---@return table|nil data Таблица чистых данных объекта
function M.get_inspect_info(go_id)
    print('get_inspect_info', go_id)

    ---@type any
    -- local world_object_uid = world_objects_state.instances[go_id]
    -- if world_object_uid then
    --     local data = world_objects_state.get(world_object_uid)
    --     return "world_object", world_object_uid, data
    -- end

    ---@type any
    local world_item_uid = world_items_state.instances[go_id]
    if world_item_uid then
        local data = world_items_state.get_item_by_uid(world_item_uid)
        return "world_item", world_item_uid, data
    end

    ---@type any
    local units_uid = units_state.instances[go_id]
    if units_uid then
        local data = units_state.get(units_uid)
        return "unit", units_uid, data
    end

    return nil, nil, nil
end

---------------------------
-- СИСТЕМНЫЕ ФУНКЦИИ (Сохранение/Загрузка)
---------------------------

---Сбор всех живых Душ для записи в файл JSON
---@return table
function M.get_full_save_data()
    print("БЭКЕНД [GameState]: Сбор снапшота вселенной RPG...")
    return {
        world_items_state = world_items_state.get_all(),
        -- containers_state = containers_state.get_all(),
        -- 🦾 Скелеты и Дракон теперь честно запечатываются в файл сохранения!
        units_state = units_state.get_all()
    }
end

---Получить полную структуру данных игрока как Универсального Юнита из реестра (WoW-Фасад)
---@return UnitInstanceData|nil Возвращает паспорт игрока из RAM
function M.get_player_data()
    if units_state and units_state.get_unit_by_uid then
        return units_state.get_unit_by_uid("player")
    end
    return nil
end

---Покадрово зафиксировать координаты игрока во внутреннем стейте юнитов (WoW-Фасад)
---@param position vector3 Си-вектор координат из player.script
function M.update_player_position(position)
    if units_state and units_state.update_data then
        -- Фасад сам зряче командует стейту обновить данные для ключа "player"
        units_state.update_data("player", {
            saved_position = position
        })
    end
end

---Универсальный Сервис-Локатор (Канон BG3 / Osiris): Каскадный поиск сущности по её UID
---@param uid string Уникальный строковый идентификатор из Tiled или фабрики ("Mage_Boss", "i_X_Y", "Main_Quest_Chest")
---@return table|nil data Возвращает RAM-паспорт Души объекта (юнита, предмета или контейнера)
function M.get_entity_by_uid(uid)
    if not uid or uid == "" or uid == hash("") then return nil end

    -- 🦾 КAСКAДНЫЙ WoW-ПОИСК:
    -- Мы последовательно заглядываем в реестры RAM по хэш-ключам. 
    -- Поиск в мапах Lua происходит за O(1) Си-тактов, поэтому нагрузка равна нулю!

    -- 1. Сначала ищем в Юнитах (Игрок, Скелеты, Драконы, Боссы из Tiled)
    if units_state and units_state.get_unit_by_uid then
        local unit_data = units_state.get_unit_by_uid(uid)
        if unit_data then return unit_data end
    end

    -- 2. Если не нашли, заглядываем в Предметы на земле (Дроп и статические шмотки)
    if world_items_state and world_items_state.get_item_by_uid then
        local item_data = world_items_state.get_item_by_uid(uid)
        if item_data then return item_data end
    end

    -- 3. Если и там глухо, проверяем интерактивные Контейнеры/Сундуки карты
    if containers_state and containers_state.get then
        local container_data = containers_state.get(uid)
        if container_data then return container_data end
    end

    -- Сущность полностью отсутствует во вселенной RAM игры
    return nil
end

-- Внутри твоего game_state.lua

---Универсальный Сервис-Локатор (Канон BG3): Каскадный перевод Си Game Object ID в строковый UID
---@param go_id hash Нативный хэш-адрес объекта на сцене движка (target_id, sender, клик мыши)
---@return string|nil uid Возвращает строковый UID ("player", "c_X_Y", "i_X_Y", "box_X_Y")
function M.get_uid_by_go_id(go_id)
    if not go_id or go_id == hash("") then return nil end

    -- 🦾 КAСКAДНЫЙ ПОИСК ИHСТАHСОВ (O(1) Си-тактов процессора):

    -- 1. Сначала проверяем, не Живой ли это Юнит (Игрок, Скелет, Дракон)
    if units_state and units_state.instances and units_state.instances[go_id] then
        return units_state.instances[go_id]
    end

    -- 2. Если не нашли, проверяем, не Предмет ли это на земле (Оружие, мешки с лутом)
    if world_items_state and world_items_state.instances and world_items_state.instances[go_id] then
        return world_items_state.instances[go_id]
    end

    -- 3. Если и там глухо, проверяем, не интерактивный ли это Контейнер (Сундук, Бочка, Шкаф)
    if containers_state and containers_state.instances and containers_state.instances[go_id] then
        return containers_state.instances[go_id]
    end

    -- Физический Си-объект полностью неизвестен бэкенду стейтов
    return nil
end


---Получить список всех зарегистрированных на сцене физических Game Object ID юнитов
---@return table<hash, string> -- Мапа, где ключ - go_id движка, а значение - строковый uid
function M.get_active_unit_instances()
    if units_state and units_state.instances then
        return units_state.instances
    end
    return {}
end

---Взвести или сбросить флаг боя для юнита в реестре RAM (ИСПРАВЛЕНО)
---@param uid string Уникальный строковый UID монстра ("c_X_Y")
---@param is_combat boolean true, если моб вступает в бой, false — если выходит
function M.set_combat(uid, is_combat)
    -- Мы легально и безопасно прокидываем вызов во внутренний units_state,
    -- полностью избавляя внешние скрипты ИИ от этой лапши!
    if units_state and units_state.set_combat then
        units_state.set_combat(uid, is_combat)
    end
end

function M.update_all_timers(dt)
    if units_state and units_state.update_all_timers then
        units_state.update_all_timers(dt)
    end
end

---Принудительно создать чистокровный Unit-паспорт для игрока в RAM при Новой Игра (ИСПРАВЛЕНО)
---@param default_props table Дефолтные характеристики (unit_id, stats и т.д.)
---@return UnitInstanceData|nil Возвращает созданную таблицу паспорта
function M.create_player_unit(default_props)
    if units_state and units_state.add then
        -- Вызываем инкапсулированный метод add через Фасад!
        units_state.add("player", default_props)
        return units_state.get_unit_by_uid("player")
    end
    return nil
end

---Раздача прилетевших из JSON данных обратно в оперативную память Lua
---@param full_data table Таблица данных из сейва
function M.restore_all(full_data)
    print("--- DEBUG: RESTORE ALL START ---")

    if not full_data then
        print("🚨 БЭКЕНД [GameState]: ОШИБКА! Данные сохранения равны NIL!")
        return
    end

    -- Твой родной зрячий дебаг-вывод ключей верхнего уровня
    for k, v in pairs(full_data) do
        local count = 0
        if type(v) == "table" then
            for _ in pairs(v) do count = count + 1 end
        end
        print(string.format("FOUND KEY: [%s] | TYPE: [%s] | ELEMENTS: [%d]", tostring(k), type(v), count))
    end

    -- 1. Реставрация Предметов на земле
    if full_data.world_items_state and world_items_state.restore_all then
        print("Restoring world_items_state...")
        world_items_state.restore_all(full_data.world_items_state)
    end

    -- 2. Реставрация Контейнеров
    if full_data.containers_state and containers_state.restore_all then
        print("Restoring containers_state...")
        containers_state.restore_all(full_data.containers_state)
    end

    -- 3. 🦾 РEСТAВРAЦИЯ МОНСТРОВ (Породоистый WoW-канон):
    -- Возвращаем Скелетов в живую память бэкенда при загрузке сейва!
    if full_data.units_state and units_state.restore_all then
        print("Restoring units_state...")
        units_state.restore_all(full_data.units_state)
    end

    print("--- DEBUG: RESTORE ALL END ---")
end

---Полная стерильная очистка всех доменов памяти для Новой Игры
function M.clear_all()
    print("БЭКЕНД [GameState]: Тотальное выжигание реестров для Новой Игры...")
    if world_items_state.clear then world_items_state.clear() end
    if containers_state.clear then containers_state.clear() end
    -- 🦾 Чистим Скелетов, страхуя рантайм от фантомных ранений прошлого прохождения!
    if units_state.clear then units_state.clear() end
end

return M

