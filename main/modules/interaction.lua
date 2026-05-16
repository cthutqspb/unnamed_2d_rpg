-- modules/interaction.lua
local M = {}

function M.handle_click(self, interaction_range, callback)
    local player_pos = go.get_position("/player")
    local my_pos = go.get_world_position()
    local dist = vmath.length(player_pos - my_pos)
    
    if dist < interaction_range then
        callback()
    else
        print("Too far:", dist)
        -- Передаем только ID цели. Никаких функций!
        msg.post("/player", "move_to_item", { item_id = go.get_id() })
    end
end

function M.get_target_under_cursor(self)
    -- Мы берем данные из твоего курсора (который в world.script или где он у тебя)
    -- Если курсор сейчас ловит collision_response от объекта:
    local hover_data = self.hovered_object -- Эту переменную должен обновлять курсор
    
    if hover_data then
        -- Возвращаем тип (для БД меню) и ссылку на объект
        return hover_data.type, hover_data.id
    end
    return nil
end

return M
