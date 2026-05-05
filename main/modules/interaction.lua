-- modules/interaction.lua
local M = {}

function M.handle_click(self, interaction_range, callback)
    local player_url = msg.url("/player")
    local player_pos = go.get_position(player_url)
    local my_pos = go.get_world_position()
    -- local player_pos = go.get_position("player")
    -- local my_pos = go.get_position()
    local dist = vmath.length(player_pos - my_pos)
    
    if dist < interaction_range then
        callback()
    else
        print("Too far:", dist)
        msg.post("player", "move_to", { target = go.get_id(), callback = callback })
    end
end

return M
