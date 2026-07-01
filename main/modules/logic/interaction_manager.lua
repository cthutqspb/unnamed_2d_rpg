local game_state = require("main.modules.game_state.game_state")
local broadcast = require("main.modules.system.broadcast")

---@class InteractionManager
local M = {}

-- =========================================================================
-- 🎯 ЖИВОЙ БОЕВОЙ СТEЙТ ТAРГEТA ИГРОКА (Единственный Источник Правды для UI):
-- =========================================================================
M.current_target_go_id = nil  -- 🚀 ТУТ ЧЕСТНО СИДИТ Си-хэш hash: [/instance8]
M.current_target_uid = nil    -- 🚀 ТУТ ЧЕСТНО СИДИТ строка "companion_skeleton_1"

---Взять существо в прицел (Взводится strictly при клике мыши в world.script)
---@param go_id hash Движковый Си-идентификатор объекта монстра
---@param uid string Уникальный строковый UID инстанса для бэкенда
function M.set_target(go_id, uid)
    if M.current_target_uid == uid then return end

    print(string.format("🎯 ИНТEРAКШEН: Захвачен фокус цели! UID: [%s] | GO_ID: %s", uid, tostring(go_id)))

    -- Запекаем ключи ПРЯМО ТУТ, без левых прослоек и прыжков!
    M.current_target_go_id = go_id
    M.current_target_uid = uid

    -- 💥 МVС-БРOДКAСТ: Сообщаем HUD фрейму и экшен-бару, что цель сменилась
    broadcast.send("target_events", {
        message_id = hash("target_changed"),
        go_id = go_id,
        uid = uid
    })
end

---Получить Си-хэш текущей цели для работы с векторами (Для пули и WASD)
---@return hash|nil
function M.get_current_target()
    return M.current_target_go_id
end

---Получить строковый UID текущей цели (Для редьюсеров и комбат-менеджера)
---@return string|nil
function M.get_current_target_uid()
    return M.current_target_uid
end

---Сбросить текущую боевую цель (При клике на чистую траву)
function M.clear_target()
    if not M.current_target_uid then return end

    -- Стерильно стираем оперативку менеджера
    M.current_target_go_id = nil
    M.current_target_uid = nil

    print("🎯 ИНТEРAКШEН: Боевая цель пуленепробиваемо сброшена.")
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

return M
