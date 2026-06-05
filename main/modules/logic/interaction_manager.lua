local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local broadcast = require("main.modules.system.broadcast")

---@class InteractionManager
---@field current_focus_ds table|nil Ссылка на data_source (модель) активного контейнера
local M = {}

-- 🎯 ЖИВОЙ БОЕВОЙ СТEЙТ ТAРГEТA (Канон WoW):
M.current_target_go_id = nil
M.current_target_uid = nil

---Взять живое существо в прицел (Чистокровный WoW-канон: фиксируем только КЛЮЧИ)
---@param go_id hash Движковый Си-идентификатор объекта монстра
---@param uid string Уникальный строковый UID инстанса для бэкенда
function M.set_target(go_id, uid)
    if M.current_target_go_id == go_id then return end

    M.current_target_go_id = go_id
    M.current_target_uid = uid

    print(string.format("🎯 ИНТEРAКШEН: Захвачен фокус цели! UID: [%s]", uid))

    -- 💥 МVС-БРOДКAСТ: Просто сообщаем худу: "Цель изменилась, иди прочитай её стейт по UID!"
    broadcast.send("target_events", {
        message_id = hash("target_changed"),
        go_id = go_id,
        uid = uid
    })
end

---Сбросить текущую боевую цель
function M.clear_target()
    if not M.current_target_go_id then return end

    M.current_target_go_id = nil
    M.current_target_uid = nil

    print("🎯 ИНТEРAКШEН: Боевая цель сброшена.")
    broadcast.send("target_events", { message_id = hash("target_lost") })
end


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
