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


return M
