local character_logic = require("main.modules.character.character_logic")
local creatures_state = require("main.modules.game_state.creatures_state")
local broadcast = require("main.modules.system.broadcast")

---@class CombatManager
local M = {}

---Универсальный атомарный метод нанесения любого урона в игре (и для автоатак мобов, и для мага)
---@param attacker_id hash|string Си-адрес или UID того, кто наносит урон
---@param target_id hash|string Си-адрес или UID цели, которая принимает урон
---@param raw_damage number Базовая величина урона до применения брони/рангов
function M.apply_damage(attacker_id, target_id, raw_damage)
    -- 🎯 РАЗВОД ЦЕЛЕЙ (Менеджер сам понимает, кого бьют)

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
        broadcast.send("combat_events", { event = "player_damaged", amount = final_damage })

    -- СЛУЧАЙ Б: Игрок (или летящий Ледяной Болт) бьет Скелета/Дракона
    else
        -- target_id здесь — это Си-идентификатор go_id тушки моба на карте Meadows
        local monster_uid = creatures_state.instances[target_id]
        if not monster_uid then return end

        local monster_data = creatures_state.get(monster_uid)
        if not monster_data or monster_data.health <= 0 then return end

        -- Списываем ХП у монстра внутри его живой бэкенд-таблицы
        monster_data.health = math.max(0, monster_data.health - raw_damage)
        print(string.format("💥 БОЙ: Юниту %s [%s] нанесено -%d урона! Живое ХП: %d/%d",
            monster_data.creature_id, monster_uid, raw_damage, monster_data.health, monster_data.max_health))

        -- Шлёма бродкаст, чтобы рамка ховера и верхняя полоска ХП цели перерисовались
        broadcast.send("combat_events", { event = "monster_damaged", go_id = target_id, uid = monster_uid })

        -- Если мертвец окончательно испустил дух:
        if monster_data.health <= 0 then
            print(string.format("💀 БОЙ: Юнит %s [%s] пал в бою!", monster_data.creature_id, monster_uid))

            -- Стираем Си-тело монстра с Meadows-земли
            go.delete(target_id)
            -- creatures_state.unregister вызовется нативно внутри final() удаляемого скрипта существа!
        end
    end
end

return M

