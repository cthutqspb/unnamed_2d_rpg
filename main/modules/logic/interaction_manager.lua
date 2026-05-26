local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")

local M = {}

M.current_focus_ds = nil -- Ссылка на data_source (items) АКТИВНОГО контейнера

function M.set_focus(ds)
    M.current_focus_ds = ds
end

function M.clear_focus()
    M.current_focus_ds = nil
end

function M.get_focus()
    return M.current_focus_ds
end

-- Этот метод для сундуков: им всегда нужен инвентарь игрока
function M.get_player_inventory()
    return player_inventory
end

function M.get_player_paperdoll()
    return player_paperdoll
end


return M
