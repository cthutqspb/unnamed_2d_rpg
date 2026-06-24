-- main/modules/unit/logic/unit_logic.lua
local game_state = require("main.modules.game_state.game_state")
local broadcast = require("main.modules.system.broadcast")
local items_db = require("main.modules.data.items_db")

---@class UnitLogicModule
local M = {}

-- =========================================================================
-- 🛡️ ВНУТРЕННИЕ СИСТЕМНЫЕ ХЕЛПЕРЫ ОБРАТНОЙ СОВМЕСТИМОСТИ
-- =========================================================================

local function resolve_unit(optional_unit)
    return optional_unit or game_state.get_player_data()
end

-- =========================================================================
-- 🦾 ГЕЙМПЛЕЙНЫЕ ПОЛИМОРФНЫЕ МЕТОДЫ (ИТЕРАЦИЯ 1)
-- =========================================================================

---Посчитать итоговое значение базовой характеристики для ЛЮБОГО юнита в игре
---@param stat_name string Имя характеристики ("strength", "agility", "intellect", "stamina")
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Живой паспорт существа из RAM реестра
---@return number total Итоговое суммарное значение стата с учетом надетого шмота
function M.get_total_stat(stat_name, unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or not unit.stats then return 0 end

    -- Жестко читаем только БАЗОВОЕ значение стата из таблицы stats (которое никогда не растет от шмота!)
    local total = unit.stats[stat_name] or 0

    -- ВРЕМЕННЫЙ МОСТ СОВМЕСТИМОСТИ ДЛЯ КУКЛЫ ШМОТА:
    if unit.is_player then
        local player_paperdoll = require("main.modules.player.player_paperdoll")
        if player_paperdoll and player_paperdoll.slots then
            for _, item_data in pairs(player_paperdoll.slots) do
                if item_data and item_data.item_id then
                    local item_cfg = items_db.get_item(item_data.item_id)
                    if item_cfg and item_cfg.stats and item_cfg.stats[stat_name] then
                        total = total + item_cfg.stats[stat_name]
                    end
                end
            end
        end
    elseif unit.paperdoll and unit.paperdoll.slots then
        for _, item_data in pairs(unit.paperdoll.slots) do
            if item_data and item_data.item_id then
                local item_cfg = items_db.get_item(item_data.item_id)
                if item_cfg and item_cfg.stats and item_cfg.stats[stat_name] then
                    total = total + item_cfg.stats[stat_name]
                end
            end
        end
    end

    return total
end

---Вычислить максимальный запас здоровья на основе текущей выносливости (Stamina)
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
---@return number max_health
function M.calculate_max_health(unit_data)
    local unit = resolve_unit(unit_data)
    if not unit then return 100 end

    -- WoW-канон: Базовое ХП игрока 100, монстров — из их базы units_db
    local base_health = 100
    if not unit.is_player then
        local units_db = require("main.modules.data.units_db")
        local db_cfg = units_db.get_unit(unit.unit_id)
        base_health = db_cfg and db_cfg.base_health or 40
    end

    -- 🛡️ ИСПРАВЛЕНО: Передаем зрячий объект 'unit' внутрь калькулятора стат!
    local total_stamina = M.get_total_stat("stamina", unit)
    return base_health + math.max(0, total_stamina - 10) * 10
end

---Вычислить максимальный запас маны на основе текущего интеллекта (Intellect)
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
---@return number max_mana
function M.calculate_max_mana(unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or unit.mana == nil then return 0 end

    local base_mana = unit.is_player and 50 or 20

    -- 🛡️ ИСПРАВЛЕНО: Передаем зрячий объект 'unit' внутрь калькулятора стат!
    local total_intellect = M.get_total_stat("intellect", unit)
    return base_mana + math.max(0, total_intellect - 10) * 5
end

---Пересчитать все производные характеристики ЛЮБОГО существа (ХП, Ману, текущие статы)
---@param unit_data table|nil
function M.update_derived_stats(unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or not unit.current_stats then return end

    -- На ходу перезаписываем текущие статы (current_stats) на основе базовых (stats) + шмот
    unit.current_stats.strength = M.get_total_stat("strength", unit)
    unit.current_stats.agility = M.get_total_stat("agility", unit)
    unit.current_stats.intellect = M.get_total_stat("intellect", unit)
    unit.current_stats.stamina = M.get_total_stat("stamina", unit)

    -- 🛡️ ИСПРАВЛЕНО: Прокидываем 'unit' в калькуляторы ресурсов, закрывая дыру дюпа!
    unit.max_health = M.calculate_max_health(unit)
    if unit.max_mana ~= nil then
        unit.max_mana = M.calculate_max_mana(unit)
    end

    local base_speed = unit.is_player and 220 or (unit.speed or 90)

    -- Задел на будущее: тут будет умножение на баффы скорости от куклы шмота или магии!
    local health_modifier = (unit.health < 20) and 0.50 or 1.0

    -- Записываем Готовый Финальный Результат в RAM-паспорт Юнита!
    unit.speed = math.floor(base_speed * health_modifier)

    if unit.is_player then
        broadcast.send("player_events", {
            message_id = hash("update_health"),
            percentage = unit.health / unit.max_health
        })
        --msg.post("game_scene:/player", "stats_changed")
    else
        broadcast.send("unit_events", {
            message_id = hash("unit_stats_changed"),
            uid = unit.uid,
            percentage = unit.health / unit.max_health
        })
    end
end

---Изменить содержимое конкретной ячейки панели способностей Юнита (Бэкенд-мутатор)
---@param bar_index number Номер панели (1, 2 или 3)
---@param slot_index number Порядковый номер ячейки (от 1 до 12)
---@param action_type "ability"|"item"|"empty" Тип действия
---@param action_id string|nil Идентификатор из базы абилок или предметов
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита (nil для фоллбека на игрока)
function M.set_action_bar_slot(bar_index, slot_index, action_type, action_id, unit_data)
    -- Хелпер resolve_unit автоматически подставит игрока, если вызвано из диспетчера!
    local unit = resolve_unit(unit_data)
    if not unit or not unit.action_bars then return end

    -- 1. Страховка: если таблицы конкретной панели в памяти юнита ещё нет — инициализируем её
    if not unit.action_bars[bar_index] then
        unit.action_bars[bar_index] = {}
    end

    -- 2. МУТИРУЕМ ПАМЯТЬ ЮНИТА: Записываем новую структуру в Single Source of Truth
    if action_type == "empty" then
        unit.action_bars[bar_index][slot_index] = nil
    else
        unit.action_bars[bar_index][slot_index] = {
            action_type = action_type,
            action_id = action_id
        }
    end

    print(string.format("💾 БЭКЕНД [unit_logic]: Изменена Панель %d, Слот %d для Юнита [%s] -> [%s: %s]",
        bar_index, slot_index, unit.uid, action_type, tostring(action_id)))

    -- Бэкенд изменил данные и реактивно сообщает интерфейсам, что пора обновить HUD!
    -- Сигналы шлем только если это ИГРОК, чтобы не спамить шину впустую
    if unit.is_player then
        broadcast.send("action_bar_events", {
            message_id = hash("action_bars_changed")
        })
        broadcast.send("inventory_events", {
            message_id = hash("inventory_changed")
        })
    end
end


--- Боевые методы

---Проверить магические щиты Юнита и поглотить входящий урон (Универсальный WoW-канон)
---@param incoming_damage number Входящий сырой урон
---@param unit_data table|nil ОПЦИОНАЛЬНО: Паспорт юнита
---@return number remaining_damage Остаток урона, который должен пойти в ХП
function M.consume_absorb_shield(incoming_damage, unit_data)
    local unit = resolve_unit(unit_data)

    -- 🛡️ ГВАРД ОТСУТСТВИЯ ЩИТА: Если щита нет вообще или он пустой — весь урон летит в ХП без изменений
    if not unit or not unit.absorb_shield or unit.absorb_shield <= 0 then
        return incoming_damage -- 🚩 ГАРАНТИРОВАННО ВОЗВРАЩАЕМ ЧИСЛО!
    end

    if unit.absorb_shield >= incoming_damage then
        -- Щит полностью впитал урон
        unit.absorb_shield = unit.absorb_shield - incoming_damage
        print(string.format("🛡️ БЭКЕНД [unit_logic]: Магический щит Юнита [%s] поглотил урон!", unit.uid))

        if unit.is_player then
            broadcast.send("player_events", { message_id = hash("update_shield"), value = unit.absorb_shield })
        end
        return 0 -- Урон по ХП равен нулю!
    else
        -- Щит пробит, гасим часть урона
        local remaining_damage = incoming_damage - unit.absorb_shield
        print(string.format("🛡️ БЭКЕНД [unit_logic]: Магический щит Юнита [%s] ПРОБИТ! Натиск: %d", unit.uid, remaining_damage))
        unit.absorb_shield = 0

        if unit.is_player then
            broadcast.send("player_events", { message_id = hash("update_shield"), value = 0 })
        end
        return remaining_damage -- 🚩 ИСПРАВЛЕНО: Теперь число честно возвращается и в этой ветке!
    end
end

---Применить получение ОЧИЩЕННОГО урона ЛЮБЫМ существом во вселенной (WoW/Pathfinder канон)
---@param final_amount number Количество дамага, который уже пробил все щиты и спасалки
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт цели, получающей урон
function M.take_damage(final_amount, unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or unit.is_dead then return end

    unit.health = unit.health - final_amount

    -- 🛡️ PATHFINDER-РАЗВОД ПО ФРАКЦИЯМ (ИСПРАВЛЕНО):
    -- Отрицательный порог смерти и падение без сознания мы считаем ТОЛЬКО для Игрока!
    -- Обычные скелеты и драконы Meadows должны красиво рассыпаться ровно при 0 ХП,
    -- чтобы не плодить на лужайке горы "бессознательных" монстров!
    local death_threshold = 0
    if unit.is_player then
        death_threshold = -M.get_total_stat("stamina", unit) -- порог от Выносливости мага
    end

    if unit.health <= death_threshold then
        unit.health = death_threshold
        unit.is_dead = true -- Тотальная смерть
        print(string.format("💀 БЭКЕНД: ЮНИТ [%s] ОКОНЧАТЕЛЬНО УМЕР!", unit.uid))
    elseif unit.health <= 0 and unit.is_player then
        print("💤 БЭКЕНД: ИГРОК БЕЗ СОЗНАНИЯ (Отрицательное ХП):", unit.health)
    end

    -- 🎯 MVC-РАЗВОД СИГНАЛОВ ИНТЕРФЕЙСА:
    if unit.is_player then
        -- Если урон получил игрок — шлем бродкаст на его HUD
        broadcast.send("player_events", {
            message_id = hash("update_health"),
            percentage = math.max(0, unit.health) / unit.max_health
        })
    else
        -- 🦾 Если урон получил моб — пуляем реактивный сигнал на сочный RimWorld-покрас 
        -- спрайта в красный цвет и мгновенное обновление полоски его Nameplate над головой!
        broadcast.send("unit_events", {
            message_id = hash("unit_damaged"),
            uid = unit.uid,
            percentage = math.max(0, unit.health) / unit.max_health
        })
    end

    M.update_derived_stats(unit)
end

--- Остальные методы
---Применить исцеление ЛЮБОМУ существе во вселенной (Универсальный WoW-канон)
---@param amount number Количество восстанавливаемого здоровья
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита (nil для фоллбека на игрока)
function M.heal(amount, unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or unit.is_dead then return end

    unit.health = math.min(unit.max_health, unit.health + amount)

    -- Pathfinder Канон: Отрицательный порог смерти считаем только для Игрока
    local death_threshold = unit.is_player and -M.get_total_stat("stamina", unit) or 0

    if unit.health > death_threshold and unit.is_dead then
        unit.is_dead = false
        print(string.format("👼 БЭКЕНД [unit_logic]: Юнит [%s] успешно воскрес из мертвых! Живое ХП: %d", unit.uid, unit.health))
    end

    -- Разводим реактивные сигналы на Nameplates и HUD игрока
    if unit.is_player then
        broadcast.send("player_events", {
            message_id = hash("update_health"),
            percentage = math.max(0, unit.health) / unit.max_health
        })
    else
        broadcast.send("unit_events", {
            message_id = hash("unit_healed"),
            uid = unit.uid,
            percentage = math.max(0, unit.health) / unit.max_health
        })
    end
end

---Потратить ману Юнита (Только если у него есть манапул)
---@param amount number Количество сжигаемой маны
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
function M.burn_mana(amount, unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or unit.mana == nil then return end

    unit.mana = math.max(0, unit.mana - amount)

    if unit.is_player then
        broadcast.send("player_events", {
            message_id = hash("update_mana"),
            percentage = unit.mana / unit.max_mana
        })
    end
end

---Восстановить ману Юнита
---@param amount number Количество восстанавливаемой маны
---@param unit_data table|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
function M.restore_mana(amount, unit_data)
    local unit = resolve_unit(unit_data)
    if not unit or unit.mana == nil then return end

    unit.mana = math.min(unit.max_mana, unit.mana + amount)

    if unit.is_player then
        broadcast.send("player_events", {
            message_id = hash("update_mana"),
            percentage = unit.mana / unit.max_mana
        })
    end
end

return M

