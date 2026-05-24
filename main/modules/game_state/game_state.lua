local world_items_state = require("main.modules.game_state.world_items_state")
local containers_state = require("main.modules.game_state.containers_state")
-- local character = require("main.modules.game_state.character_state") -- на будущее

local M = {}

function M.get_entity_info(go_id)
    -- Спрашиваем контейнеры
    local c_uid = containers_state.instances[go_id]
    if c_uid then return "container", c_uid end

    -- Спрашиваем лут
    local l_uid = world_items_state.instances[go_id]
    if l_uid then return "loot", l_uid end

    return nil
end


---------------------------
-- СИСТЕМНЫЕ ФУНКЦИИ (Сохранение/Загрузка)
---------------------------

-- Сбор всех данных для записи в файл
function M.get_full_save_data()
    return {
        world_items_state = world_items_state.get_all(),
        containers_state = containers_state.get_all(),
        -- stats = character.get_all()
    }
end

-- Раздача данных при загрузке
function M.restore_all(full_data)
    print("--- DEBUG: RESTORE ALL START ---")
    
    if not full_data then
        print("ERROR: full_data is NIL")
    else
        -- Цикл по ключам верхнего уровня, чтобы понять вложенность
        for k, v in pairs(full_data) do
            local count = 0
            if type(v) == "table" then
                for _ in pairs(v) do count = count + 1 end
            end
            print(string.format("FOUND KEY: [%s] | TYPE: [%s] | ELEMENTS: [%d]", tostring(k), type(v), count))
        end
        
        -- Полный дамп структуры в консоль (если таблица не гигантская)
        -- pprint(full_data) 
    end

    -- Сама логика восстановления
    if full_data.world_items_state then
        print("Restoring world_items_state...")
        world_items_state.restore_all(full_data.world_items_state)
    end
    
    if full_data.containers_state then
        print("Restoring containers_state...")
        containers_state.restore_all(full_data.containers_state)
    end
    
    print("--- DEBUG: RESTORE ALL END ---")
end


-- Полная очистка (для новой игры)
function M.clear_all()
    world_items_state.clear()
    containers_state.clear()
end

---------------------------
-- API ДЛЯ ТУЛТИПОВ И ИНСПЕКЦИИ
---------------------------

function M.get_data_by_type(kind, uid)
    -- ВЫВОД ВСЕХ ПРЕДМЕТОВ В КОНСОЛЬ ДЛЯ ТЕСТА
    print("--- FULL WORLD ITEMS REGISTRY ---")
    local all_items = world_items_state.get_all()
    for k, v in pairs(all_items) do
        print(string.format("KEY: [%s] | ID: [%s] | DYNAMIC: [%s]", 
            tostring(k), 
            tostring(v.item_id), 
            tostring(v.is_dynamic)))
    end
    print("---------------------------------")

    print('get_data_by_type', kind, uid)
    if kind == "container" then
        return containers_state.get(uid)
    elseif kind == "loot" then
        return world_items_state.get_item_by_uid(uid)
    end
    return nil
end


return M

