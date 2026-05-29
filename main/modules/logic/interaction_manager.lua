local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local broadcast = require("main.modules.system.broadcast")

---@class InteractionManager
---@field current_focus_ds table|nil Ссылка на data_source (модель) активного контейнера
local M = {}

M.current_focus_ds = nil -- Ссылка на data_source (items) АКТИВНОГО контейнера

---Установить фокус на модель данных открытого контейнера
---@param ds table Модель данных инвентаря сундука/бочки
function M.set_focus(ds)
    M.current_focus_ds = ds
end

---Очистить фокус взаимодействия (вызывается при закрытии окон)
function M.clear_focus()
    M.current_focus_ds = nil

    -- 🎯 MVC-РЕШЕНИЕ: Бэкенд просто сообщает миру, что фокус закрыт.
    -- Никаких графических drag_manager тут больше нет!
    broadcast.send("ui_events", {
        message_id = hash("focus_lost")
    })
end

---Получить модель данных текущего открытого контейнера
---@return table|nil
function M.get_focus()
    return M.current_focus_ds
end

---Получить чистую модель инвентаря игрока
---@return table
-- Этот метод для сундуков: им всегда нужен инвентарь игрока
function M.get_player_inventory()
    return player_inventory
end

---Получить чистую модель куклы (снаряжения) игрока
---@return table
function M.get_player_paperdoll()
    return player_paperdoll
end


return M
