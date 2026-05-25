-- interaction_manager.lua
local M = {}

M.active_container = nil -- Ссылка на data_source открытого окна (сундук/торговец)

function M.set_focus(data_source)
    M.active_container = data_source
end

function M.clear_focus()
    M.active_container = nil
end

function M.get_focus()
    return M.active_container
end

return M

