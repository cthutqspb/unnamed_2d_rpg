local character_data = require("main.modules.character.character_data")
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

---Получить движковый ID текущей цели для работы с миром и векторами
---@return hash|nil
function M.get_current_target()
    return M.current_target_go_id
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

function M.get_player_action_bar(index)
    return character_data.player.action_bars[index] or {}
end

return M
