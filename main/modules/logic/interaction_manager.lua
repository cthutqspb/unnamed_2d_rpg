local game_state = require("main.modules.game_state.game_state")
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
    if M.get_current_target_uid() == uid then return end

    print(string.format("🎯 ИНТEРAКШEН: Захвачен фокус цели! UID: [%s]", uid))

    if game_state and game_state.set_combat_state then
        game_state.set_combat_state("player", uid)
    end

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
    local uid = M.get_current_target_uid()
    if not uid then return nil end

    -- Наносекундный Си-прыжок в реестр за go_id, который туда вшил units_state.register!
    local target = game_state.get_entity_by_uid(uid)
    return target and target.go_id
end

---Получить движковый ID текущей цели для работы с миром и векторами
function M.get_current_target_uid()
    local player = game_state.get_player_data()
    return player and player.combat_target_uid
end

---Сбросить текущую боевую цель
function M.clear_target()
    if not M.current_target_go_id then return end

    M.current_target_go_id = nil
    M.current_target_uid = nil

    -- 🦾 ОЧИЩАЕМ БОЕВОЙ СТEЙТ МАГА В RAM ЧЕРЕЗ ФАСАД:
    if game_state and game_state.set_combat_state then
        game_state.set_combat_state("player", nil)
    end

    print("🎯 ИНТEРAКШEН: Боевая цель сброшена.")
    broadcast.send("target_events", { message_id = hash("target_lost") })
end

-- =========================================================================
-- СЕКЦИЯ ВЗАИМОДЕЙСТВИЯ С КОНТЕЙНЕРАМИ (СУНДУКИ / БОЧКИ):
-- =========================================================================
M.current_focus_ds = nil -- Ссылка на data_source (items) АКТИВНОГО контейнера

---Установить фокус на модель данных открытого контейнера
---@param ds table Модель данных инвентаря сундука/бочки
function M.set_focus(ds)
    M.current_focus_ds = ds
end

---Очистить фокус взаимодействия (вызывается при закрытии окон)
function M.clear_focus()
    M.current_focus_ds = nil
    broadcast.send("ui_events", {
        message_id = hash("focus_lost")
    })
end

---Получить модель данных текущего открытого контейнера
---@return table|nil
function M.get_focus()
    return M.current_focus_ds
end

---Прослойка-мост для обратной совместимости универсальной сетки (Слепой транзит)
---@param bar_index number
---@return table|nil
function M.get_player_action_bar(bar_index)
    -- Менеджер кликов мыши сам ничего не знает про мага, он просто перенаправляет 
    -- запрос в Фасад вселенной, прося выдать бары для UID = "player"!
    return game_state.get_unit_action_bar("player", bar_index)
end

return M
