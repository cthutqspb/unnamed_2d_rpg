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

---Применить получение урона персонажем
---@param amount number Количество входящего дамага
function M.take_damage(amount)
    data.player.health = math.max(0, data.player.health - amount)

    -- 🎯 Бросаем сигнал изменения здоровья в канал игрока. HUD его поймает и обновит полоску ХП!
     broadcast.send("player_events", {
        message_id = hash("update_health"),
        percentage = data.player.health / data.player.max_health
    })
end

---Применить исцеление персонажа
---@param amount number Количество восстанавливаемого здоровья
function M.heal(amount)
    data.player.health = math.min(data.player.max_health, data.player.health + amount)

    -- 🎯 Бросаем сигнал исцеления
     broadcast.send("player_events", {
        message_id = hash("update_health"),
        percentage = data.player.health / data.player.max_health
    })
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

