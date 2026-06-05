local data = require("main.modules.character.character_data")
local paperdoll = require("main.modules.player.player_paperdoll")
local items_db = require("main.modules.data.items_db")
local broadcast = require("main.modules.system.broadcast") -- Подключаем шину событий

---@class CharacterLogicModule
local M = {}

---Посчитать итоговое значение базовой характеристики с учетом всех надетых на куклу шмоток
---@param stat_name string Имя характеристики ("strength", "agility", "intellect", "stamina")
---@return number total Итоговое суммарное значение стата
function M.get_total_stat(stat_name)
    local total = data.player.stats[stat_name] or 0

    -- Пробегаемся по слотам бэкенд-модели куклы персонажа
    for _, item_data in pairs(paperdoll.slots) do
        if item_data and item_data.item_id then
            local item_cfg = items_db.get_item(item_data.item_id)
            if item_cfg and item_cfg.stats and item_cfg.stats[stat_name] then
                total = total + item_cfg.stats[stat_name]
            end
        end
    end
    return total
end

---Вычислить максимальный запас здоровья на основе текущей выносливости (Stamina)
---@return number max_health
function M.calculate_max_health()
    local base = 100
    local total_stamina = M.get_total_stat("stamina")
    return base + math.max(0, total_stamina - 10) * 10
end

---Вычислить максимальный запас маны на основе текущего интеллекта (Intellect)
---@return number max_mana
function M.calculate_max_mana()
    local base = 50
    local total_intellect = M.get_total_stat("intellect")
    return base + math.max(0, total_intellect - 10) * 5
end

---Пересчитать все производные характеристики персонажа (ХП, Ману, статы от шмота) 
---и уведомить мир и интерфейсы об изменениях
function M.update_derived_stats()
    -- Обновляем текущие статы в глобальном стейте памяти
    data.player.current_stats.strength = M.get_total_stat("strength")
    data.player.current_stats.agility = M.get_total_stat("agility")
    data.player.current_stats.intellect = M.get_total_stat("intellect")
    data.player.current_stats.stamina = M.get_total_stat("stamina")

    data.player.max_health = M.calculate_max_health()
    data.player.max_mana = M.calculate_max_mana()

    -- 🎯 MVC-РЕШЕНИЕ: Вместо msg.post в GUI, шлем реактивный Redux-бродкаст в хад!
    broadcast.send("player_events", {
        message_id = hash("update_health"),
        percentage = data.player.health / data.player.max_health
    })

    -- Системный пинок физическому объекту игрока в мире (оставляем, это не GUI)
    msg.post("game_scene:/player", "stats_changed")
end

---Применить получение ОЧИЩЕННОГО урона персонажем
---@param final_amount number Количество дамага, который уже пробил все щиты и спасалки
function M.take_damage(final_amount)
    data.player.health = data.player.health - final_amount

    -- Pathfinder Канон: если ХП ушло в минус, но не пробило смертельный порог выносливости,
    -- персонаж просто падает без сознания, но флаг is_dead остается false!
    local death_threshold = -M.get_total_stat("stamina") -- например, -25 ХП

    if data.player.health <= death_threshold then
        data.player.health = death_threshold
        data.player.is_dead = true -- Тотальная смерть
        print("💀 ИГРОК ОКОНЧАТЕЛЬНО УМЕР!")
    elseif data.player.health <= 0 then
        print("💤 ИГРОК БЕЗ СОЗНАНИЯ (Отрицательное ХП):", data.player.health)
    end

    -- Бросаем сигнал на HUD. Математику процентов пишем аккуратно, учитывая минусы
    broadcast.send("player_events", {
        message_id = hash("update_health"),
        percentage = math.max(0, data.player.health) / data.player.max_health
    })
end

---Применить исцеление персонажа (С поддержкой отладочного воскрешения)
---@param amount number Количество восстанавливаемого здоровья
function M.heal(amount)
    data.player.health = math.min(data.player.max_health, data.player.health + amount)

    -- 🎯 МИРОВОЙ ПОРОГ ВОСКРЕШЕНИЯ (Канон Pathfinder):
    -- Вытаскиваем текущий лимит тотальной смерти (минус стамина)
    local death_threshold = -M.get_total_stat("stamina") -- например, -25 ХП

    -- Если хил вытащил ХП из могилы и поднял его ВЫШЕ смертельного лимита:
    if data.player.health > death_threshold and data.player.is_dead then
        data.player.is_dead = false
        print("👼 ЛОГИКА: Персонаж успешно воскрес из мертвых! Живое ХП:", data.player.health)

        -- Сюда завтра можно повесить: broadcast.send("player_events", { message_id = hash("player_resurrected") })
        -- Чтобы привязать анимацию вспышки света над головой мага!
    end

    -- 🎯 Бросаем сигнал исцеления на HUD (проценты считаем аккуратно)
    broadcast.send("player_events", {
        message_id = hash("update_health"),
        percentage = math.max(0, data.player.health) / data.player.max_health
    })
end

function M.burn_mana(amount)
    data.player.mana = data.player.mana - amount

    broadcast.send("player_events", {
        message_id = hash("update_mana"),
        percentage = math.max(0, data.player.mana) / data.player.max_mana
    })
end

function M.restore_mana(amount)
    data.player.mana = data.player.mana + amount

    broadcast.send("player_events", {
        message_id = hash("update_mana"),
        percentage = math.max(0, data.player.mana) / data.player.max_mana
    })
end

---Проверить магические щиты игрока и поглотить входящий урон
---@param incoming_damage number Входящий сырой урон
---@return number remaining_damage Остаток урона, который пробил щиты и должен пойти в ХП
function M.consume_absorb_shield(incoming_damage)
    -- Если щита нет или он пустой — весь урон летит в ХП без изменений
    if not data.player.absorb_shield or data.player.absorb_shield <= 0 then
        return incoming_damage
    end

    if data.player.absorb_shield >= incoming_damage then
        -- Щит полностью впитал урон
        data.player.absorb_shield = data.player.absorb_shield - incoming_damage
        print("🛡️ ЛОГИКА: Магический щит полностью поглотил урон! Остаток щита:", data.player.absorb_shield)

        -- Шлем бродкаст на HUD, чтобы перерисовать полоску щита (если она есть)
        broadcast.send("player_events", { message_id = hash("update_shield"), value = data.player.absorb_shield })
        return 0 -- Урон по ХП равен нулю!
    else
        -- Щит пробит, гасим часть урона
        local remaining_damage = incoming_damage - data.player.absorb_shield
        print("🛡️ ЛОГИКА: Магический щит ПРОБИТ! Остаток урона летит в ХП:", remaining_damage)
        data.player.absorb_shield = 0

        broadcast.send("player_events", { message_id = hash("update_shield"), value = 0 })
        return remaining_damage -- Возвращаем то, что пробило щит
    end
end

---Добавить или отнять базовую характеристику персонажа (например, при прокачке левелапа)
---@param stat_name string Имя стата
---@param value number Величина изменения (может быть отрицательной)
function M.add_stat(stat_name, value)
    if data.player.stats[stat_name] then
        data.player.stats[stat_name] = data.player.stats[stat_name] + value

        -- Если изменились выносливость или интеллект — принудительно пересчитываем пулы ХП/Маны
        if stat_name == "stamina" or stat_name == "intellect" then
            M.update_derived_stats()
        end
    end
end

return M

