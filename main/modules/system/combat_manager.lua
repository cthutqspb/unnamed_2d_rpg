local unit_logic = require("main.modules.unit.logic.unit_logic")
local game_state = require("main.modules.game_state.game_state")
local units_db = require("main.modules.data.units_db")
local abilities_db = require("main.modules.data.abilities_db")
local broadcast = require("main.modules.system.broadcast")

---@class CombatManager
local M = {}

local active_effects = {}

local DEFAULT_MIN_DAMAGE     = 1    -- Гарантированный минимальный урон, если в базе абилок пусто
local DEFAULT_MAX_DAMAGE     = 2    -- Гарантированный максимальный урон, если в базе абилок пусто

---@param caster_uid string КТО использует способность (Си-адрес или "player")
---@param target_uid string КОГО бьем (Си-адрес выделенного монстра или игрока)
---@param ability_id string ID способности из базы данных ("melee_attack")
function M.execute_ability(caster_uid, target_uid, ability_id)
    -- 1. WoW-канон: Если цели вообще нет в таргете
    if not target_uid then
        if caster_uid == "player" then
            msg.post("main:/gui_manager#hud", "show_screen_error", { text = "НЕТ ЦЕЛИ" })
        end
        return
    end

    ---@type UnitInstance
    local caster_unit = game_state.get_entity_by_uid(caster_uid)
    ---@type UnitInstance
    local target_unit = game_state.get_entity_by_uid(target_uid)
    local is_possible, error_reason = unit_logic.check_cast_possibility(caster_unit, ability_id, target_unit)

    if not is_possible then
        -- Если кастует Игрок — сочно переводим код ошибки в понятный человеку текст для экрана!
        if caster_uid == "player" then
            local log_text = "Неизвестная ошибка заклинания"
            if error_reason == "OUT_OF_RANGE" then log_text = "НЕ ДОСТАТЬ"
            elseif error_reason == "NO_MANA" then log_text = "НЕДОСТАТОЧНО МАНЫ"
            elseif error_reason == "NO_TARGET" then log_text = "НЕТ ЦЕЛИ"
            elseif error_reason == "INVALID_TARGET" then log_text = "ЦЕЛЬ МЕРТВА"
            end

            msg.post("main:/gui_manager#hud", "show_screen_error", { text = log_text })

            broadcast.send("log_events", {
                message_id = hash("log_message"),
                channel = "combat",
                text = log_text
            })
        end
        return -- НАМЕРТВО РУБИМ ВЫПОЛНЕНИЕ! Каст сорван, урон не нанесется, мана спасена!
    end

    local cfg = abilities_db.get_ability(ability_id)
    if not cfg then return end

   -- Внутри твоего комбат-менеджера на проверке стоимости заклинания:

    if cfg.cost then
        local resource_type = cfg.cost.resource or "mana"
        local value = cfg.cost.value or 0

        -- 🦾 СТЕРИЛЬНЫЙ ГВАРД СТОИМОСТИ (ИСПРАВЛЕНО):
        -- Проверяем: жив ли кастер, совпадает ли его тип ресурса с ценой заклинания, 
        -- и хватает ли ему текущей энергии в RAM (.current) на совершение каста!
        if value > 0 and caster_unit and caster_unit.resource and caster_unit.resource.type == resource_type then
            if caster_unit.resource.current >= value then

                -- Пинаем наш зрячий мутатор памяти в units_state!
                -- Вызов game_state меняем на units_state!
                game_state.consume_unit_resource(caster_uid, resource_type, value)

            else
                print("❌ БОЁВКА: Не хватает ресурса для каста заклинания!")
                return false -- Отрезаем каст
            end
        end
    end


    local min_dmg = cfg.damage and cfg.damage.min or DEFAULT_MIN_DAMAGE
    local max_dmg = cfg.damage and cfg.damage.max or DEFAULT_MAX_DAMAGE
    local final_damage = math.random(min_dmg, max_dmg)

    if caster_unit and cfg.damage.scaling_stats then
        for attribute_name, factor in pairs(cfg.damage.scaling_stats) do
            local current_attribute_value = caster_unit.attributes[attribute_name] or 0
            final_damage = final_damage + math.floor(current_attribute_value * factor)
        end
    end

    -- НАКАТЫВАЕМ ЭКСПОНЕНЦИАЛЬНЫЙ РОСТ ДЛЯ МОНСТРОВ:
    if caster_unit and not caster_unit.is_player then
        local db_cfg = units_db.get_unit(caster_unit.unit_id)
        if db_cfg and db_cfg.progression.health_growth then
            local dmg_modifier = math.pow(db_cfg.progression.damage_growth, caster_unit.level - 1)
            final_damage = math.floor(final_damage * dmg_modifier)
        end
    end

    -- =========================================================================
    -- 🚀 УЛЬТИМАТИВНЫЙ СПАВНЕР ФИЗИЧЕСКИХ СНАРЯДОВ (ДОБАВЛЕНО НАМЕРТВО):
    -- =========================================================================
    -- Если у абилки в БД прописан путь к фабрике (например, cfg.projectile_factory = "#frostbolt_factory")
    if cfg.projectile_factory and cfg.delivery_type == "projectile" then
        local spawn_pos = go.get_position(caster_unit.go_id)

        -- Спавним абсолютно пустую Си-гошку на сцене
        local proj_go_id = factory.create(cfg.projectile_factory, spawn_pos, nil, {
            caster_go_id = caster_unit.go_id,
            target_go_id = target_unit.go_id,
            ability_id   = hash(ability_id)
        })

        -- Регистрируем снаряд в нашей чистой Lua-памяти комбат-менеджера!
        table.insert(active_effects, {
            go_id        = proj_go_id,
            caster_unit  = caster_unit,
            target_unit  = target_unit,
            caster_uid   = caster_uid,
            target_uid   = target_uid,
            damage       = final_damage,
            speed        = cfg.projectile_speed or 500,
            ability_id   = ability_id
        })

    else
        -- =========================================================================
        -- 💥 МГНОВЕННЫЙ НАНОСИТЕЛЬ УРОНА (Мили-атаки, Блинк, Мгновенные лучи)
        -- =========================================================================
        -- 1. Сначала шёлково бьем бэкендом в RAM-паспорт цели!
        M.apply_damage(caster_unit, target_unit, final_damage)

        -- 2. ⚡ WOW-КАНОН МОЛНИИ (ВРЕЗАНО ЮВЕЛИРНО):
        if cfg.delivery_type == "beam" and cfg.fx and cfg.fx.particle_fx then
            local spawn_pos = go.get_position(caster_unit.go_id)

            local fx_props = {
                duration = cfg.fx.duration or 0.4,
                caster_go_id = caster_unit.go_id,
                target_go_id = target_unit.go_id,
                ability_id   = hash(ability_id)
            }

            -- Спавним контейнер и ловим его Си-Id со сцены!
            local fx_go_id = factory.create(cfg.projectile_factory, spawn_pos, nil, fx_props)

            -- 🚀 РЕГИСТРИРУЕМ ЛУЧ МОЛНИИ В ТВОЮ ЖЕ ТАБЛИЦУ (ИСПРАВЛЕНО):
            -- Мы просто кидаем гошку в твой готовый active_projectiles!
            -- Нам не нужны левые unit-ссылки для луча, только Си-хэши гошек для тригонометрии!
            table.insert(active_effects, {
                go_id         = fx_go_id,
                is_beam       = true, -- 🦾 ГЛАВНЫЙ МАРКЕР: "Я не пуля, я лазер!"
                caster_go_id  = caster_unit.go_id,
                target_go_id  = target_unit.go_id,
                ability_id    = ability_id
            })

            print(string.format("⚡ БЭКЕНД [Combat]: Молния [%s] визуально прошила цель!", ability_id))
        end
        -- =========================================================================
    end
end

function M.simulate_combat_effects(dt)
    -- Идем с конца в начало, чтобы безопасно удалять элементы из таблицы
    for i = #active_effects, 1, -1 do
        local effect = active_effects[i]

        -- Нативная Си-проверка: существует ли еще игровой объект эффекта на сцене
        local exists_proj, proj_pos = pcall(go.get_position, effect.go_id)

        -- =========================================================================
        -- ⚡ КАСКАД Б: СИМУЛЯЦИЯ ЛУЧА МОЛНИИ (ТВОЯ MIDPOINT СТЯЖКА + UNIFORM СКЕЙЛ)
        -- =========================================================================
        if effect.is_beam then
            -- Запрашиваем Си-координаты участников напрямую по хэшам гошек
            local exists_caster, caster_pos = pcall(go.get_position, effect.caster_go_id)
            local exists_target, target_pos = pcall(go.get_position, effect.target_go_id)

            if not exists_proj or not exists_caster or not exists_target then
                -- Если кто-то умер или удален — тушим гошку луча пулей и чистим RAM
                if exists_proj then go.delete(effect.go_id) end
                table.remove(active_effects, i)
            else
                -- 🚀 1. ВЫЧИСЛЯЕМ СЕРЕДИНУ ВЕКТОРА (MIDPOINT КАНОН):
                -- Комбат-менеджер сам ставит контейнер молнии ровно между вами!
                local midpoint = (caster_pos + target_pos) * 0.5
                go.set_position(midpoint, effect.go_id)

                -- 2. Считаем реальную дистанцию и направление
                local direction = target_pos - caster_pos
                local distance = vmath.length(direction)

                -- Ротируем кабель молнии носом строго по оси направления между вами
                local angle = math.atan2(direction.y, direction.x)
                go.set_rotation(vmath.quat_rotation_z(angle), effect.go_id)

                -- 🚀 3. ТВОЙ ПРОПОРЦИОНАЛЬНЫЙ UNIFORM-СКЕЙЛ ОТ ЦЕНТРА:
                -- Делим реальную дистанцию на базовую длину эмиттера из редактора (200)
                local base_beam_length = 200
                local scale_factor = distance / base_beam_length

                -- Аппаратно расширяем края молнии влево к магу и вправо к скелету за 0 тактов!
                go.set_scale(vmath.vector3(scale_factor, scale_factor, scale_factor), effect.go_id)
            end

        -- =========================================================================
        -- 🟢 КАСКАД А: СИМУЛЯЦИЯ ЛЕТЯЩЕЙ ПУЛИ (ТВОЙ ДЕВСТВЕННЫЙ ПОДХОД БЕЗ ИЗМЕНЕНИЙ)
        -- =========================================================================
        else
            local exists_target, target_pos = pcall(go.get_position, effect.target_unit.go_id)

            if not exists_proj or not exists_target then
                -- Если цель умерла от чего-то другого, удаляем пулю
                if exists_proj then go.delete(effect.go_id) end
                table.remove(active_effects, i)
            else
                -- Двигаем пулю СИЛАМИ КОМБАТ МЕНЕДЖЕРА
                local direction = target_pos - proj_pos
                local distance = vmath.length(direction)

                -- ЧЕСТНЫЙ ИМПАКТ (Как в WoW):
                if distance <= (effect.speed * dt) or distance <= 15 then
                    -- Вытаскиваем свежие, актуальные карточки из RAM-реестра по UID прямо в этот кадр
                    local caster = game_state.get_entity_by_uid(effect.caster_uid)
                    local target = game_state.get_entity_by_uid(effect.target_uid)

                    if caster and target then
                        -- Наносим урон строго по актуальному стейту живых существ!
                        M.apply_damage(caster, target, effect.damage)
                        print(string.format("💥 WOW-ИМПАКТ: %s сочно долетел до цели!", effect.ability_id))
                    end

                    go.delete(effect.go_id) -- Удаляем гошку со сцены
                    table.remove(active_effects, i) -- Чистим из таблицы
                else
                    -- Если еще летит — перемещаем и поворачиваем гошку на сцене
                    local move_vector = vmath.normalize(direction) * effect.speed * dt
                    local new_pos = proj_pos + move_vector
                    go.set_position(new_pos, effect.go_id)

                    local angle = math.atan2(direction.y, direction.x)
                    go.set_rotation(vmath.quat_rotation_z(angle), effect.go_id)
                end
            end
        end
        -- =========================================================================
    end
end

-- -- Этот метод мы вызываем в главном update игры (например, в main.script)
-- function M.simulate_combat_effects(dt)
--     -- Идем с конца в начало, чтобы безопасно удалять элементы из таблицы
--     for i = #active_effects, 1, -1 do
--         local effect = active_effects[i]
--         
--         -- Проверяем, существует ли еще пуля и ее цель на сцене
--         local exists_proj, proj_pos = pcall(go.get_position, effect.go_id)
--         local exists_target, target_pos = pcall(go.get_position, effect.target_unit.go_id)
--
--         if not exists_proj or not exists_target then
--             -- Если цель умерла от чего-то другого, удаляем пулю
--             if exists_proj then go.delete(effect.go_id) end
--             table.remove(active_effects, i)
--         else
--             -- Двигаем пулю СИЛАМИ КОМБАТ МЕНЕДЖЕРА
--             local direction = target_pos - proj_pos
--             local distance = vmath.length(direction)
--
--             -- ЧЕСТНЫЙ ИМПАКТ (Как в WoW):
--             if distance <= (effect.speed * dt) or distance <= 15 then
--                 -- Вытаскиваем свежие, актуальные карточки из RAM-реестра по UID прямо в этот кадр
--                 local caster = game_state.get_entity_by_uid(effect.caster_uid)
--                 local target = game_state.get_entity_by_uid(effect.target_uid)
--
--                 if caster and target then
--                     -- Наносим урон строго по актуальному стейту живых существ!
--                     M.apply_damage(caster, target, effect.damage)
--                     print(string.format("💥 WOW-ИМПАКТ: %s сочно долетел до цели!", effect.ability_id))
--                 end
--
--                 go.delete(effect.go_id) -- Удаляем гошку со сцены
--                 table.remove(active_effects, i) -- Чистим из таблицы
--             else
--                 -- Если еще летит — перемещаем и поворачиваем гошку на сцене
--                 local move_vector = vmath.normalize(direction) * effect.speed * dt
--                 local new_pos = proj_pos + move_vector
--                 go.set_position(new_pos, effect.go_id)
--
--                 local angle = math.atan2(direction.y, direction.x)
--                 go.set_rotation(vmath.quat_rotation_z(angle), effect.go_id)
--             end
--         end
--     end
-- end

---Универсальный атомарный метод нанесения любого урона во вселенной Meadows (WoW / BG3 канон)
---@param caster_unit UnitInstance Живой RAM-паспорт атакующего существа
---@param target_unit UnitInstance Живой RAM-паспорт жертвы, которая принимает удар
---@param raw_damage number Базовая величина урона до применения брони/рангов
function M.apply_damage(caster_unit, target_unit, raw_damage)
    -- Жесткий Си-засов: если кто-то из участников испарился из памяти — рубим кадр
    if not caster_unit or not target_unit then return end

    -- =========================================================================
    -- 🦾 ПОЛИМОРФНАЯ ЗАПИСЬ ОБИДЧИКА В RAM-ПАСПОРТ (WoW Hate-List Канон):
    -- =========================================================================
    -- Нам глубоко насрать, кто кого бьет — игрок моба, моб игрока или скелет кабана!
    -- Есть ФАКТ атаки по существу! И жертва (target_unit) пуленепробиваемо записывает 
    -- в свое поле .last_attacker_uid уникальный строковый UID нападавшего (caster_unit.uid)!
    -- 0 сообщений в скрипты, 0 бродкастов — чистая, мгновенная мутация ядра памяти в RAM!
    if caster_unit.uid and caster_unit.uid ~= "" then
        print("АТАКА ЮНИТА", target_unit.unit_id)
        target_unit.combat.last_attacker_uid = caster_unit.uid
    end
    -- =========================================================================

    local log_message = "Combat event occurred"

    -- 🦾 СВЯЩЕННЫЙ ААА-ПОЛИМОРФИЗМ (Убрали лапшу с hash("/player")):
    -- Нам больше не нужно угадывать строки и хэши! Мы смотрим на честный, запеченный флаг 
    -- .is_player прямо внутри RAM-паспорта той цели, которая ПРИНИМАEТ урон!
    local is_target_player = target_unit.is_player == true

    -- =========================================================================
    -- СЛУЧАЙ А: Любой юнит (моб/босс/эффект) бьет нашего ИГРОКА
    -- =========================================================================
    if is_target_player then
        if target_unit.combat.is_dead then return end

        -- 🦾 ЗРЯЧИЙ ЮНИТ-АБСОРБ: Скармливаем паспорт игрока напрямую в ядро логики!
        local final_damage = unit_logic.consume_absorb_shield(raw_damage, target_unit)

        if final_damage <= 0 then
            broadcast.send("combat_events", { event = "player_absorb", amount = raw_damage })
            log_message = string.format("🛡️ БОЙ: Щит игрока полностью поглотил удар юнита %s!",
                caster_unit.unit_id or "Unknown")
        else
            -- 🦾 ЗРЯЧИЙ ЮНИТ-ДАМАГ: Вычитаем ХП из живой RAM-карточки мага
            unit_logic.take_damage(final_damage, target_unit)

            local attacker_name = caster_unit.unit_id or "Unknown"
            log_message = string.format("💥 БОЙ: Юнит %s [%s] нанес -%d урона игроку!",
                attacker_name, caster_unit.uid, final_damage)

            broadcast.send("combat_events", { event = "player_damaged", amount = final_damage })
        end

    -- =========================================================================
    -- СЛУЧАЙ Б: Игрок (или летящий Фростболт) бьет Скелета/Дракона/Монстра
    -- =========================================================================
    else
        if target_unit.combat.is_dead then return end

        -- 🦾 УЛЬТИМАТИВНЫЙ ПОЛИМОРФИЗМ: Скармливаем паспорт скелета в то же самое ядро!
        -- Метод вычтет ХП из RAM-карточки моба, а если здоровье упадет в ноль — сам взведет .is_dead = true!
        unit_logic.take_damage(raw_damage, target_unit)

        log_message = string.format("💥 БОЙ [combat_manager]: Юниту %s [%s] нанесено -%d урона! Живое ХП: %d/%d",
            target_unit.unit_id, target_unit.uid, raw_damage, target_unit.health_resource.current, target_unit.health_resource.max)

        -- Шлём бродкаст для рамки ховера и Nameplate целей, забирая go_id прямо из паспорта моба!
        broadcast.send("combat_events", {
            event = "unit_attacked",
            go_id = target_unit.go_id,
            uid = target_unit.uid
        })

        -- 🚀 РЕАКЦИЯ НА СМЕРТЬ/РАНЕНИЕ СИ-ТЕЛ НА СЦЕНЕ (СВЯЗКА С ДВИЖКОМ):
        -- Нам больше не нужны локаторы! Мы шлем Си-пакет напрямую по запеченному target_unit.go_id!
        if target_unit.go_id then
            if target_unit.combat.is_dead then
                log_message = string.format("💀 БОЙ [combat_manager]: Юнит %s [%s] пал в бою!", target_unit.unit_id, target_unit.uid)
                msg.post(target_unit.go_id, "on_unit_died")
            else
                msg.post(target_unit.go_id, "on_unit_damaged")
            end
        end
    end

    -- 🎯 БЕЗОПАСНЫЙ СИНГЛ-ВЫХОД ЛОГА: 
    print(log_message)
    broadcast.send("log_events", { message_id = hash("log_message"), channel = "combat", text = log_message })
end

return M
