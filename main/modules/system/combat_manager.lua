local unit_logic = require("main.modules.unit.logic.unit_logic")
local game_state = require("main.modules.game_state.game_state")
local units_db = require("main.modules.data.units_db")
local abilities_db = require("main.modules.data.abilities_db")
local broadcast = require("main.modules.system.broadcast")

---@class CombatManager
local M = {}

local MELEE_THRESHOLD_RANGE = 80   -- Порог, ниже которого способность считается ближним боем (в пикселях)
local DEFAULT_MELEE_RANGE    = 16   -- Базовый ренж замаха оружия ближнего боя по умолчанию
local DEFAULT_UNIT_HITBOX    = 64   -- Дефолтный размер хитбокса юнита, если RAM пустой
local DEFAULT_MIN_DAMAGE     = 1    -- Гарантированный минимальный урон, если в базе абилок пусто
local DEFAULT_MAX_DAMAGE     = 2    -- Гарантированный максимальный урон, если в базе абилок пусто

---Попытаться использовать способность ЛЮБЫМ юнитом по выбранной цели (WoW-канон — ИСПРАВЛЕНО)
---@param attacker_id hash|string КТО использует способность (Си-адрес или "player")
---@param target_go_id hash|nil КОГО бьем (Си-адрес выделенного монстра или игрока)
---@param ability_id string ID способности из базы данных ("melee_attack")
function M.execute_ability(attacker_id, target_go_id, ability_id)
    -- 1. WoW-канон: Если цели вообще нет в таргете
    if not target_go_id then
        if attacker_id == "player" then
            msg.post("main:/gui_manager#hud", "show_screen_error", { text = "НЕТ ЦЕЛИ" })
        end
        return
    end

    -- 2. Физический гвард существования Си-объекта цели на Meadows-карте
    local exists, target_pos = pcall(go.get_position, target_go_id)
    if not exists or not target_pos then
        if attacker_id == "player" then
            msg.post("main:/gui_manager#hud", "show_screen_error", { text = "ЦЕЛЬ МЕРТВА" })
        end
        return
    end

    -- 3. ЗРЯЧИЙ БЭКЕНД-ГВАРД СМЕРТИ ЦЕЛИ:
    local target_uid = game_state.get_uid_by_go_id(target_go_id) or tostring(target_go_id)
    local target_data = game_state.get_entity_by_uid(target_uid)

    if target_data and target_data.is_dead then
        if attacker_id == "player" then
            msg.post("main:/gui_manager#hud", "show_screen_error", { text = "ЦЕЛЬ МЕРТВА" })
        end
        return
    end

    -- Вытаскиваем чертеж абилки из нашей новой чистой базы способностей
    local cfg = abilities_db.get_ability(ability_id)
    if not cfg then return end

    -- =========================================================================
    -- 🎯 4. УНИВЕРСАЛЬНЫЙ РАСЧЕТ ДИСТАНЦИИ (УБРАНО РАЗДЕЛЕНИЕ НА МОБОВ И ИГРОКА)
    -- =========================================================================
    local attacker_go = (attacker_id == "player") and "game_scene:/player" or attacker_id
    local attacker_pos = go.get_position(attacker_go)
    local distance = vmath.length(attacker_pos - target_pos)

    -- 🛡️ ЕДИНЫЙ ИСТОЧНИК ПРАВДЫ: Изначально берем чистый ренж оружия/заклинания из базы абилок
    local allowed_range = cfg.range or DEFAULT_MELEE_RANGE

    -- WoW/BG3 КАНОН: Если это способность БЛИЖНЕГО БОЯ (ренж в базе меньше 80 пикселей),
    -- мы принудительно расширяем зону атаки на сумму радиусов хитбоксов ОБОИХ участников боя!
    -- Теперь и для мага, и для скелета (16 + 32 + 32) лимит замаха станет равен честным 80 пикселям, 
    -- а для дальнего боя (Frostbolt 350) allowed_range останется строго 350!
    if allowed_range < MELEE_THRESHOLD_RANGE then
        local attacker_uid = (attacker_id == "player") and "player" or game_state.get_uid_by_go_id(attacker_id)
        local attacker_data = game_state.get_entity_by_uid(attacker_uid)

        local attacker_hitbox = attacker_data and attacker_data.hitbox_size or DEFAULT_UNIT_HITBOX
        local target_hitbox = target_data and target_data.hitbox_size or DEFAULT_UNIT_HITBOX

        -- 🦾 ЕДИНАЯ ДЛЯ ВСЕХ ФОРМУЛА ХИТБОКСОВ: (Радиус_1 + Радиус_2) + Ренж_Из_Базы
        allowed_range = (attacker_hitbox / 2) + (target_hitbox / 2) + allowed_range
    end

    -- ГВАРД ДИСТАНЦИИ: Если цель слишком далеко
    print("ATTACKER", attacker_id, distance, allowed_range)
    if distance > allowed_range then
        if attacker_id == "player" then
            msg.post("main:/gui_manager#hud", "show_screen_error", { text = "НЕ ДОСТАТЬ" })
        end
        return
    end

    -- 5. ААА-РАСЧЕТ МУЛЬТИ-СТАТ УРОНА ОТ ХАРАКТЕРИСТИК:
    local min_dmg = cfg.damage and cfg.damage.min or DEFAULT_MIN_DAMAGE
    local max_dmg = cfg.damage and cfg.damage.max or DEFAULT_MAX_DAMAGE
    local final_damage = math.random(min_dmg, max_dmg)

    local attacker_uid = (attacker_id == "player") and "player" or game_state.get_uid_by_go_id(attacker_id)
    local attacker_data = game_state.get_entity_by_uid(attacker_uid)

    if attacker_data and cfg.damage.scaling_stats then
        for stat_name, factor in pairs(cfg.damage.scaling_stats) do
            local current_stat_value = attacker_data.current_stats[stat_name] or 0
            final_damage = final_damage + math.floor(current_stat_value * factor)
        end
    end

    -- НАКАТЫВАЕМ ЭКСПОНЕНЦИАЛЬНЫЙ РОСТ ДЛЯ МОНСТРОВ:
    if attacker_data and not attacker_data.is_player then 
        local db_cfg = units_db.get_unit(attacker_data.unit_id)
        if db_cfg and db_cfg.health_growth then
            local dmg_modifier = math.pow(db_cfg.damage_growth, attacker_data.level - 1)
            final_damage = math.floor(final_damage * dmg_modifier)
        end
    end
    print("ATTACK", attacker_id, final_damage)
    -- 6. 💥 ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ: Наносим атомарный урон!
    M.apply_damage(attacker_id, target_go_id, final_damage)
end

---Универсальный атомарный метод нанесения любого урона в игре (Канон WoW / BG3)
---@param attacker_id hash|string Си-адрес или UID того, кто наносит урон
---@param target_id hash|string Си-адрес или UID цели, которая принимает урон
---@param raw_damage number Базовая величина урона до применения брони/рангов
function M.apply_damage(attacker_id, target_id, raw_damage)
    local log_message = "Combat event occurred"

    -- 🎯 ЗРЯЧЕЕ РАЗРЕШЕНИЕ НАПАДАЮЩЕГО ЧЕРЕЗ КАСКАДНЫЙ ФАСАД:
    local attacker_uid = game_state.get_uid_by_go_id(attacker_id) or tostring(attacker_id)
    local attacker_data = game_state.get_entity_by_uid(attacker_uid)

    -- 🛡️ ААА-РАЗВОД ФРАКЦИЙ (ИСПРАВЛЕНО):
    -- Добавляем в проверку hash("/player"), чтобы Си-хэш со слэшем от ИИ монстров 
    -- гарантированно распознавался как Игрок! Теперь Случай А сработает на 100% точно,
    -- урон полетит в щиты мага, а Случай Б будет обрабатывать строго скелетов!
    local is_target_player = (
        target_id == "player" or
        target_id == hash("player") or
        target_id == "/player" or
        target_id == hash("/player") -- 👈 ВОТ ЭТОТ СИ-ЩИТ СПАСЕТ БОЁВКУ!
    )
    -- =========================================================================
    -- СЛУЧАЙ А: Моб (или босс) бьет нашего Игрока (ИСПРАВЛЕНО)
    -- =========================================================================
    if is_target_player then
        local player_data = game_state.get_player_data()
        if not player_data or player_data.is_dead then return end

        -- 🦾 ЗРЯЧИЙ ЮНИТ-АБСОРБ: Явно передаем паспорт игрока вторым аргументом!
        local final_damage = unit_logic.consume_absorb_shield(raw_damage, player_data)

        if final_damage <= 0 then
            broadcast.send("combat_events", { event = "player_absorb", amount = raw_damage })
            log_message = string.format("🛡️ БОЙ: Щит игрока полностью поглотил удар юнита %s!",
                attacker_data and attacker_data.unit_id or "Unknown")
        else
            -- 🦾 ЗРЯЧИЙ ЮНИТ-ДАМАГ: Явно передаем паспорт игрока вторым аргументом!
            unit_logic.take_damage(final_damage, player_data)

            local attacker_name = attacker_data and attacker_data.unit_id or "Unknown"
            log_message = string.format("💥 БОЙ: Юнит %s [%s] нанес -%d урона игроку!",
                attacker_name, attacker_uid, final_damage)

            broadcast.send("combat_events", { event = "player_damaged", amount = final_damage })
        end

    -- =========================================================================
    -- СЛУЧАЙ Б: Игрок (или летящий Ледяной Болт) бьет Скелета/Дракона 
    -- =========================================================================
    else
        -- 🎯 СЕРВИС-ЛОКАТОР: Зряче переводим Си-хэш цели в строку через Фасад
        local unit_uid = game_state.get_uid_by_go_id(target_id) or tostring(target_id)
        local unit_data = game_state.get_entity_by_uid(unit_uid)

        if not unit_data or unit_data.is_dead then return end

        -- Скармливаем паспорт скелета в наше универсальное ядро логики
        unit_logic.take_damage(raw_damage, unit_data)

        log_message = string.format("💥 БОЙ [combat_manager]: Юниту %s [%s] нанесено -%d урона! Живое ХП: %d/%d",
            unit_data.unit_id, unit_uid, raw_damage, unit_data.health, unit_data.max_health)

        -- Шлёма бродкаст для рамки ховера и Nameplate целей
        broadcast.send("combat_events", { event = "unit_attacked", go_id = target_id, uid = unit_uid })

        -- РЕАКЦИЯ НА СМЕРТЬ/РАНЕНИЕ СИ-ТЕЛ:
        if unit_data.is_dead then
            log_message = string.format("💀 БОЙ [combat_manager]: Юнит %s [%s] пал в бою!", unit_data.unit_id, unit_uid)
            msg.post(target_id, "on_unit_died")
        else
            msg.post(target_id, "on_unit_damaged")
        end
    end

    -- 🎯 БЕЗОПАСНЫЙ СИНГЛ-ВЫХОД ЛОГА: 
    -- Строка гарантированно улетит в шину бродкастов на чат-экран, без досрочных Си-обрывов!
    print(log_message)
    broadcast.send("log_events", { message_id = hash("log_message"), channel = "combat", text = log_message })
end

return M
