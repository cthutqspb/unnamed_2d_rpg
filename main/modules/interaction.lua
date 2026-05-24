-- modules/interaction.lua
local window_manager = require("main.gui.components.managers.window_manager")

local M = {}

-- Выносим константы, чтобы не "мусорить" в памяти каждый кадр
local GROUPS = { hash("interactable"), hash("loot"), hash("enemy") }
local OFFSET = 10

function M.handle_click(self, interaction_range, callback)
    -- 1. Если мышь над интерфейсом, клик в мир не должен проходить
    if window_manager.is_over_ui() then
        return
    end

    local player_pos = go.get_position("game_scene:/player")
    local my_pos = go.get_world_position()
    local dist = vmath.length(player_pos - my_pos)
    
    if dist < interaction_range then
        callback()
    else
        print("Too far:", dist)
        -- Передаем только ID цели. Никаких функций!
        msg.post("game_scene:/player", "move_to_item", { item_id = go.get_id() })
    end
end

-- function M.get_target_under_cursor(self)
--     -- Мы берем данные из твоего курсора (который в world.script или где он у тебя)
--     -- Если курсор сейчас ловит collision_response от объекта:
--     local hover_data = self.hovered_object -- Эту переменную должен обновлять курсор
--     
--     if hover_data then
--         -- Возвращаем тип (для БД меню) и ссылку на объект
--         return hover_data.type, hover_data.id
--     end
--     return nil
-- end



-- Для КЛИКА (берем один ID)
function M.get_target_under_cursor(world_pos)
    local from1 = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
    local to1 = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)
    
    local res = physics.raycast(from1, to1, GROUPS)
    
    if not res then
        local from2 = vmath.vector3(world_pos.x - OFFSET, world_pos.y - OFFSET, 10)
        local to2 = vmath.vector3(world_pos.x + OFFSET, world_pos.y + OFFSET, -10)
        res = physics.raycast(from2, to2, GROUPS)
    end

    return res and res.id or nil
end

-- Для ТУЛТИПА (берем список всех попаданий)
function M.get_all_targets_under_cursor(world_pos)
    -- Используем наклонный луч, чтобы Box2D корректно считал пересечения
    local from = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
    local to = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)
    
    local results = physics.raycast(from, to, GROUPS, { all = true })
    
    if results and #results > 0 then
        -- Сортируем: fraction 0 (ближе к from/камере) -> 1 (дальше)
        table.sort(results, function(a, b) 
            return a.fraction < b.fraction 
        end)
        return results
    end
    
    return nil
end



return M
