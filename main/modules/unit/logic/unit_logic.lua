-- main/modules/unit/logic/unit_logic.lua
local broadcast = require("main.modules.system.broadcast")
local items_db = require("main.modules.data.items_db")
local abilities_db = require("main.modules.data.abilities_db")
--local character_data = require("main.modules.character.character_data")

---@class UnitLogicModule
local M = {}

local MELEE_THRESHOLD_RANGE = 80   -- Порог, ниже которого способность считается ближним боем (в пикселях)
local DEFAULT_MELEE_RANGE    = 16   -- Базовый ренж замаха оружия ближнего боя по умолчанию
local DEFAULT_UNIT_HITBOX    = 64   -- Дефолтный размер хитбокса юнита, если RAM пустой


-- =========================================================================
-- 🦾 ГЕЙМПЛЕЙНЫЕ ПОЛИМОРФНЫЕ МЕТОДЫ (ИТЕРАЦИЯ 1)
-- =========================================================================

---Посчитать итоговое значение базовой характеристики для ЛЮБОГО юнита в игре
---@param stat_name string Имя характеристики ("strength", "agility", "intellect", "stamina")
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Живой паспорт существа из RAM реестра
---@return number total Итоговое суммарное значение сгтата с учетом надетого шмота
function M.get_total_stat(stat_name, unit)
    if not unit or not unit.base_stats then return 0 end

    -- Читаем генетическую базу стата
    local total = unit.base_stats[stat_name] or 0

    -- 🦾 УЛЬТИМАТИВНЫЙ ПОЛИМОРФИЗМ (ИСПРАВЛЕНО):
    -- Больше никаких require("player_paperdoll") и разделений на игрока/мобов!
    -- Код просто лезет в .paperdoll.slots объекта, который сейчас обсчитывается.
    -- Если это маг — посчитает мага. Если это скелет — посчитает скелета!
    if unit.paperdoll and unit.paperdoll.slots then

        for i, item_data in pairs(unit.paperdoll.slots) do
            --print("TOTAL 2",i, item_data.item_id)
            -- for k,v in pairs(item_data) do
            --    print("AAA", k,v)
            -- end
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
---@return number max_health
function M.calculate_max_health(unit)
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
---@return number max_mana
function M.calculate_max_mana(unit)
    if not unit or unit.mana == nil then return 0 end

    local base_mana = unit.is_player and 50 or 20

    -- 🛡️ ИСПРАВЛЕНО: Передаем зрячий объект 'unit' внутрь калькулятора стат!
    local total_intellect = M.get_total_stat("intellect", unit)
    return base_mana + math.max(0, total_intellect - 10) * 5
end

---Пересчитать все производные характеристики ЛЮБОГО существа (ХП, Ману, текущие статы)
---@param unit UnitInstanceData|nil
function M.update_derived_stats(unit)
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

--- Боевые методы
---Проверить магические щиты Юнита и поглотить входящий урон (Универсальный WoW-канон)
---@param incoming_damage number Входящий сырой урон
---@param unit UnitInstanceData|nil ОПЦИОНАЛЬНО: Паспорт юнита
---@return number remaining_damage Остаток урона, который должен пойти в ХП
function M.consume_absorb_shield(incoming_damage, unit)
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт цели, получающей урон
function M.take_damage(final_amount, unit)
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита (nil для фоллбека на игрока)
function M.heal(amount, unit)
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
function M.burn_mana(amount, unit)
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
---@param unit UnitInstanceData|nil 🎯 ОПЦИОНАЛЬНО: Паспорт юнита
function M.restore_mana(amount, unit)
    if not unit or unit.mana == nil then return end

    unit.mana = math.min(unit.max_mana, unit.mana + amount)

    if unit.is_player then
        broadcast.send("player_events", {
            message_id = hash("update_mana"),
            percentage = unit.mana / unit.max_mana
        })
    end
end

---@class RequirementResult
---@field is_ok boolean
---@field errors table<string, boolean>
---@field reason string|nil

---Универсальный ААА-Валидатор требований предметов для любых существ (Игрока и Мобoв)
---@param item_cfg table Конфиг предмета из items_db
---@param unit UnitInstanceData|nil RAM-паспорт существа (UnitInstanceData / карточка из реестра)
---@return RequirementResult
function M.check_item_requirements(item_cfg, unit)
    if not unit then
        return { is_ok = false, errors = {}, reason = "NO_UNIT_PASSED" }
    end

    ---@type RequirementResult
    local results = {
        is_ok = true,
        errors = {},
        reason = nil
    }

    -- Если у шмотки в базе вообще нет блока required = { level = X } — она доступна сразу!
    if not item_cfg.required then
        return results
    end

    --🦾 Всеядный цикл: Сверяем ТТХ шмотки с RAM-паспортом любого существа
    for req_id, req_val in pairs(item_cfg.required) do
        local unit_val = 0
        local stat_ok = true
        --print("REQ ID", req_id, req_val)
        if req_id == "level" then
            -- ИСПРАВЛЕНО: Читаем уровень любого юнита во вселенной!
            unit_val = unit.level or 1
            stat_ok = (unit_val >= req_val)
            if not stat_ok then results.reason = "low_level" end

        elseif req_id == "resource" then
            if req_val == "mana" then
                --Проверяем мана-ресурс у любого существа
                stat_ok = (unit.max_mana and unit.max_mana > 0) or false
                if not stat_ok then results.reason = "no_mana_resource" end
            end

        else
            -- Если у моба нет статов (мало ли, голый волк), фоллбэк в 0 защитит от крэша
            local stats_table = unit.current_stats or unit.base_stats
            unit_val = (stats_table and stats_table[req_id]) or 0
            stat_ok = (unit_val >= req_val)
            if not stat_ok then results.reason = "low_stats" end
        end

        if not stat_ok then
            results.is_ok = false
            results.errors[req_id] = true
        end
    end

    return results
end

---Титановый ААА-Валидатор Способностей (Полная изоляция от циклических зависимостей)
---@param caster UnitInstanceData|nil table RAM-паспорт того, кто кастует (UnitInstanceData / карточка существа)
---@param ability_id string ID способности ("frostbolt")
---@param target UnitInstanceData|nil RAM-паспорт цели (UnitInstanceData / карточка моба)
---@return boolean is_possible Можно ли применить?
---@return string|nil error_reason Строковый ключ ошибки ("OUT_OF_RANGE", "NO_TARGET", "NO_MANA")
function M.check_cast_possibility(caster, ability_id, target)
    -- 1. Вытаскиваем статический чертеж способности из твоей базы абилок
    local cfg = abilities_db.get_ability(ability_id)
    if not cfg then return false, "UNKNOWN_ABILITY" end

    -- 2. СИ-ЗАЩИТА: Если паспорт кастера потерялся по дороге
    if not caster then return false, "NO_CASTER" end

    if not target then
        return false, "NO_TARGET"
    end

    if target.is_dead then
        return false, "INVALID_TARGET" -- Судья выдаст четкий вердикт!
    end


    --с этим не работает
    -- if target.go_id then
    --     local exists, target_pos = pcall(go.get_position, target.go_id) -- 🦾 ТУТ СТРОГО GO_ID, А НЕ СТРОКА UID!
    --     if not exists or not target_pos then
    --         return false, "INVALID_TARGET" -- Объекта физически уже нет на сцене
    --     end
    -- end

    -- 3. ГВАРД РЕСУРСОВ: Хладнокровно проверяем ману персонажа
    if cfg.cost and cfg.cost.resource == "mana" then
        if (caster.mana or 0) < (cfg.cost.value or 0) then
            return false, "NO_MANA" -- НЕДОСТАТОЧНО МАНЫ!
        end
    end

    -- 4. ГВАРД НАЛИЧИЯ ЦЕЛИ И RANGE ДАЛЬНОСТИ ПО ТВОЕМУ КАНОНУ:
    if cfg.requires_target then
        -- КЕЙС А: Способность требует цель, а в руках пусто -> Нужна цель!
        if not target then
            return false, "NO_TARGET"
        end

        -- КЕЙС Б: Цель есть -> Считаем расстояние в RAM-мире по сохраненным координатам
        local player_pos = caster.saved_position
        local target_pos = target.saved_position

                if player_pos and target_pos then
            -- Считаем чистую Meadows-дистанцию в пикселях между центрами существ в RAM
            local dist = vmath.length(target_pos - player_pos)

            -- 🛡️ ЕДИНЫЙ ИСТОЧНИК ПРАВДЫ: Берем базовый ренж из чертежа абилки
            local base_range = cfg.range or 16
            local max_allowed_range = base_range

            -- =========================================================================
            -- 🦾 WOW/BG3 КАНОН ХИТБОКСОВ БЛИЖНЕГО БОЯ (ИНТЕГРИРОВАНО НАМЕРТВО):
            -- =========================================================================
            -- Если это способность ближнего замаха (ренж меньше 80 пикселей),
            -- мы легально расширяем зону атаки на СУММУ РАДИУСОВ ОБОИХ участников боя!
            if base_range < 80 then
                local caster_radius = (caster.hitbox_size or 64) / 2
                local target_radius = (target.hitbox_size or 64) / 2

                -- Формула: Радиус_Кастера + Радиус_Цели + Базовый_Замах
                max_allowed_range = caster_radius + target_radius + base_range
            else
                -- 📐 ТВОЙ СВЯТОЙ ОБМАН ДЛЯ ДАЛЬНЕГО БОЯ (Frostbolt 350):
                -- Для магии хитбокс самого мага не важен, но большая туша босса 
                -- должна ловить стрелу своим краем, поэтому добавляем только радиус цели!
                local target_radius = (target.hitbox_size or 64) / 2
                max_allowed_range = base_range + target_radius
            end
            -- =========================================================================

            -- Если цель убежала дальше рассчитанного Meadows-лимита
            if dist > max_allowed_range then
                return false, "OUT_OF_RANGE"
            end
        end
    end

    -- Способность полностью легальна, Meadows-конвейер чист!
    return true, nil
end

return M

