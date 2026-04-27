local M = {}

function M.get_screen_position(node)
    local x, y = 0, 0
    local current = node
    
    while current do
        local pos = gui.get_position(current)
        x = x + pos.x
        y = y + pos.y
        current = gui.get_parent(current)
    end
    
    return x, y
end

return M
