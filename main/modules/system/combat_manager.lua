local character_logic = require("main.modules.character.character_logic")
local creatures_state = require("main.modules.game_state.creatures_state")
local abilities_db = require("main.modules.data.abilities_db")
local broadcast = require("main.modules.system.broadcast")

---@class CombatManager
local M = {}

---Попытаться использовать способность игрока по выбранной цели
---@param ability_id string ID способности из базы данных (например, "melee_attack")
---@param target_go_id hash|nil Си-адрес выделенного монстра
function M.execute_ability(ability_id, target_go_id)
    -- 1. WoW-канон: Если цели вообще нет в таргете
    if not target_go_id then
        msg.post("main:/gui_manager#hud", "show_screen_error", { text = "НЕТ ЦЕЛИ" })
        return
    end
    
     -- 🎯 ТИТАНОВЫЙ БОЕВОЙ ГВАРД (Фикс спама по трупам):
    -- Безопасно проверяем, существует ли еще этот Си-объект на карте Meadows.
    -- Если моб уже был удален через go.delete(), pcall вернет false, 
    -- и мы тихо выйдем из комбат-цикла, сбросив таргет, без краша игры!
    local exists, target_pos = pcall(go.get_position, target_go_id)
    
    if not exists or not target_pos then
        print("⚔️ БОЙ: Цель уже стерта из мира (мертва). Блокируем атаку.")
        -- Опционально: можешь послать Си-сигнал в interaction_manager, чтобы он сбросил current_target_go_id в nil
        msg.post("main:/gui_manager#hud", "show_screen_error", { text = "ЦЕЛЬ МЕРТВА" })
        return
    end
    
    
    local cfg = abilities_db.get_ability(ability_id)
    if not cfg then return end

    -- 3. Вычисляем дистанцию между игроком и целью в мире Defold
    local player_pos = go.get_position("game_scene:/player")
    local target_pos = go.get_position(target_go_id)
    local distance = vmath.length(player_pos - target_pos)

    -- Страхуем range из конфига (если там 0, ставим 50px для удара посохом)
    local allowed_range = (cfg.range and cfg.range > 0) and cfg.range or 80

    -- 4. 🛡️ ГВАРД ДИСТАНЦИИ: Если цель слишком далеко
    if distance > allowed_range then
        print(string.format("⚠️ БОЙ [CombatManager]: Не достать! Дистанция: %.2f | Предел: %d", distance, allowed_range))
        msg.post("main:/gui_manager#hud", "show_screen_error", { text = "НЕ ДОСТАТЬ" })
        return -- Наглухо прерываем выполнение боевого цикла
    end

    -- 5. Проверка Кулдауна (Задел на будущее: тут будет проверка твоего swing-таймера или GCD)
    -- ...

    -- 6. Расчет урона (Берем min/max из твоего конфига способностей)
    local min_dmg = cfg.damage and cfg.damage.min or 0
    local max_dmg = cfg.damage and cfg.damage.max or 1
    local final_damage = math.random(min_dmg, max_dmg)

    -- 7. 💥 ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ: Наносим атомарный урон через твой родной метод!
    M.apply_damage("player", target_go_id, final_damage)
end

---Универсальный атомарный метод нанесения любого урона в игре (и для автоатак мобов, и для мага)
---@param attacker_id hash|string Си-адрес или UID того, кто наносит урон
---@param target_id hash|string Си-адрес или UID цели, которая принимает урон
---@param raw_damage number Базовая величина урона до применения брони/рангов
function M.apply_damage(attacker_id, target_id, raw_damage)
    -- 🎯 РАЗВОД ЦЕЛЕЙ (Менеджер сам понимает, кого бьют)
    local log_message = nil;
    -- СЛУЧАЙ А: Моб (или босс) бьет нашего Игрока
    if target_id == "player" or target_id == hash("player") or target_id == "/player" then
        -- СЛОЙ 1: Абсорб-щиты. Просим логику игрока поглотить урон
        -- Менеджеру плевать, как уменьшается щит в памяти, он просто получает ОСТАТОК цифры!
        local final_damage = character_logic.consume_absorb_shield(raw_damage)

        -- Если щит сожрал вообще весь урон, выходим из боевого цикла
        if final_damage <= 0 then
            broadcast.send("combat_events", { event = "player_absorb", amount = raw_damage })
            return
        end

        -- СЛОЙ 2: Спасительные эффекты ("Крылья" / Смерть)
        -- Здесь мы точно так же завтра сможем спросить у buff_manager: "Сработают ли крылья?"
        -- А пока — просто скармливаем чистый, пробивший щиты урон в модель здоровья!
        character_logic.take_damage(final_damage)
        
        local creature_uid = creatures_state.instances[attacker_id]
        if not creature_uid then return end

        local creature_data = creatures_state.get(creature_uid)
        if not creature_data or creature_data.health <= 0 then return end

        log_message = string.format("💥 БОЙ: Юнит %s [%s] нанес -%d урона игроку!", creature_data.creature_id, creature_uid, final_damage)

        broadcast.send("combat_events", { event = "player_damaged", amount = final_damage })

    -- СЛУЧАЙ Б: Игрок (или летящий Ледяной Болт) бьет Скелета/Дракона
    else
        -- target_id здесь — это Си-идентификатор go_id тушки моба на карте Meadows
        local creature_uid = creatures_state.instances[target_id]
        if not creature_uid then return end

        local creature_data = creatures_state.get(creature_uid)
        if not creature_data or creature_data.health <= 0 then return end

        -- Списываем ХП у монстра внутри его живой бэкенд-таблицы
        creature_data.health = math.max(0, creature_data.health - raw_damage)
        log_message = string.format("💥 БОЙ: Юниту %s [%s] нанесено -%d урона! Живое ХП: %d/%d",
            creature_data.creature_id, creature_uid, raw_damage, creature_data.health, creature_data.max_health)
        print(log_message)

        -- Шлёма бродкаст, чтобы рамка ховера и верхняя полоска ХП цели перерисовались
        broadcast.send("combat_events", { event = "creature_attacked", go_id = target_id, uid = creature_uid })

        -- Если мертвец окончательно испустил дух:
        if creature_data.health <= 0 then
            log_message = string.format("💀 БОЙ: Юнит %s [%s] пал в бою!", creature_data.creature_id, creature_uid)
            print(log_message)
            msg.post(target_id, "on_creature_died")
            -- Стираем Си-тело монстра с Meadows-земли

            -- go.delete(target_id)
            -- creatures_state.unregister вызовется нативно внутри final() удаляемого скрипта существа!
        end
    end

    broadcast.send("log_events", { message_id = hash("log_message"), channel = "combat", text = log_message })
end

return M

