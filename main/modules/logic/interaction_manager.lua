local units_state = require("main.modules.game_state.units_state")
local character_data = require("main.modules.character.character_data")
local broadcast = require("main.modules.system.broadcast")

---@class InteractionManager
local M = {}

-- =========================================================================
-- 🎯 ЕДИНСТВЕННЫЙ ИСТОЧНИК ПРАВДЫ ДЛЯ СИ-ВЕКТОРОВ (ДВИЖКОВЫЙ ФОКУС):
-- =========================================================================
-- Си-хэш гошки (hash: [/instance8]) мы оставляем тут, так как бэкенд памяти 
-- units_state ничего не знает про Defold-гошки и не должен хранить Си-адреса!
M.current_target_go_id = nil

---Взять существо в прицел (Взводится strictly при клике мыши в world.script)
---@param go_id hash Движковый Си-идентификатор объекта монстра
---@param uid string Уникальный строковый UID инстанса для бэкенда
function M.set_target(go_id, uid)
    -- Идём напрямую в Single Source of Truth — в живой RAM-паспорт нашего мага!
    local player = units_state.get(character_data.PLAYER_UID)
    if not player then return end

    if player.combat.combat_target_uid == uid then return end

    print(string.format("🎯 ИНТEРAКШEН: Захвачен фокус цели! UID: [%s] | GO_ID: %s", uid, tostring(go_id)))

    -- 🦾 АТОМАРНАЯ ЗАПИСЬ В ЕДИНЫЙ ИСТОЧНИК ПРАВДЫ:
    M.current_target_go_id = go_id
    player.combat.combat_target_uid = uid -- Запекли строковый UID прямо в Душу мага в RAM!

    -- Оповещаем HUD-контроллер. Строго выверенное ААА-имя ивента!
    broadcast.send("target_events", {
        message_id = hash("target_changed"),
        uid = uid,
        go_id = go_id
    })
end

---Сбросить текущую боевую цель (При клике на чистую траву)
function M.clear_target()
    local player = units_state.get(character_data.PLAYER_UID)
    if not player or not player.combat.combat_target_uid or player.combat.combat_target_uid == "" then return end

    -- Стерильно выжигаем память из реестра мира
    M.current_target_go_id = nil
    player.combat.combat_target_uid = nil -- Стерли цель из Души мага!

    print("🎯 ИНТEРAКШEН: Боевая цель пуленепробиваемо сброшена в RAM.")

    -- Выровненное, красивейшее имя ивента потери фокуса! Без всяких deferred!
    broadcast.send("target_events", {
        message_id = hash("target_lost")
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
    local player = units_state.get(character_data.PLAYER_UID)
    return player and player.combat.combat_target_uid or nil
end

-- =========================================================================
-- СЕКЦИЯ КОНТЕЙНЕРОВ (Оставляй твой оригинальный идеальный код без изменений)
-- =========================================================================
M.current_focus_ds = nil
function M.set_focus(ds) M.current_focus_ds = ds end
function M.clear_focus() M.current_focus_ds = nil; broadcast.send("ui_events", { message_id = hash("focus_lost") }) end
function M.get_focus() return M.current_focus_ds end

return M

