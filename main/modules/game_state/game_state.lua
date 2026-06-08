local world_items_state = require("main.modules.game_state.world_items_state")
local containers_state = require("main.modules.game_state.containers_state")
local creatures_state = require("main.modules.game_state.creatures_state")

local M = {}

---Узнать тип объекта и получить его чистые данные по go_id из мира (из рейкаста)
---@param go_id hash Идентификатор игрового объекта из физического луча мыши
---@return string|nil kind Тип объекта ("world_object", "world_item", "creature")
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
    local creatures_uid = creatures_state.instances[go_id]
    if creatures_uid then
        local data = creatures_state.get(creatures_uid)
        return "creature", creatures_uid, data
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
        containers_state = containers_state.get_all(),
        -- 🦾 Скелеты и Дракон теперь честно запечатываются в файл сохранения!
        creatures_state = creatures_state.get_all()
    }
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
    if full_data.creatures_state and creatures_state.restore_all then
        print("Restoring creatures_state...")
        creatures_state.restore_all(full_data.creatures_state)
    end

    print("--- DEBUG: RESTORE ALL END ---")
end

---Полная стерильная очистка всех доменов памяти для Новой Игры
function M.clear_all()
    print("БЭКЕНД [GameState]: Тотальное выжигание реестров для Новой Игры...")
    if world_items_state.clear then world_items_state.clear() end
    if containers_state.clear then containers_state.clear() end
    -- 🦾 Чистим Скелетов, страхуя рантайм от фантомных ранений прошлого прохождения!
    if creatures_state.clear then creatures_state.clear() end
end

return M

