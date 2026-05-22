local world_items = require("main.modules.game_state.world_items_state")
local containers = require("main.modules.game_state.containers_state")
-- local character = require("main.modules.game_state.character_state") -- на будущее

local M = {}

---------------------------
-- СИСТЕМНЫЕ ФУНКЦИИ (Сохранение/Загрузка)
---------------------------

-- Сбор всех данных для записи в файл
function M.get_full_save_data()
    return {
        world_items = world_items.get_all(),
        containers = containers.get_all(),
        -- stats = character.get_all()
    }
end

-- Раздача данных при загрузке
function M.restore_all(full_data)
    if not full_data then return end
    
    world_items.restore_all(full_data.world_items)
    containers.restore_all(full_data.containers)
end

-- Полная очистка (для новой игры)
function M.clear_all()
    world_items.clear()
    containers.clear()
end

---------------------------
-- API ДЛЯ ТУЛТИПОВ И ИНСПЕКЦИИ
---------------------------

function M.get_data_by_type(kind, uid)
    print('get_data_by_type', kind, uid)
    if kind == "container" then
        print('container uid', containers.get(uid))
        return containers.get(uid)
    elseif kind == "loot" then
        return world_items.get_item_by_uid(uid)
    end
    return nil
end


return M

