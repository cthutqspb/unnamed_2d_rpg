local unit_logic = require("main.modules.unit.logic.unit_logic")
local game_state = require("main.modules.game_state.game_state")
local units_db = require("main.modules.data.units_db")
local abilities_db = require("main.modules.data.abilities_db")
local broadcast = require("main.modules.system.broadcast")

---@class CombatManager
local M = {}

local DEFAULT_MIN_DAMAGE     = 1    -- Гарантированный минимальный урон, если в базе абилок пусто
local DEFAULT_MAX_DAMAGE     = 2    -- Гарантированный максимальный урон, если в базе абилок пусто

---Попытаться использовать способность ЛЮБЫМ юнитом по выбранной цели (WoW-канон — ИСПРАВЛЕНО)
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

    local caster_unit = game_state.get_entity_by_uid(caster_uid)
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
        for stat_name, factor in pairs(cfg.damage.scaling_stats) do
            local current_stat_value = caster_unit.current_stats[stat_name] or 0
            final_damage = final_damage + math.floor(current_stat_value * factor)
        end
    end

    -- НАКАТЫВАЕМ ЭКСПОНЕНЦИАЛЬНЫЙ РОСТ ДЛЯ МОНСТРОВ:
    if caster_unit and not caster_unit.is_player then
        local db_cfg = units_db.get_unit(caster_unit.unit_id)
        if db_cfg and db_cfg.health_growth then
            local dmg_modifier = math.pow(db_cfg.damage_growth, caster_unit.level - 1)
            final_damage = math.floor(final_damage * dmg_modifier)
        end
    end

    -- =========================================================================
    -- 🚀 УЛЬТИМАТИВНЫЙ СПАВНЕР ФИЗИЧЕСКИХ СНАРЯДОВ (ДОБАВЛЕНО НАМЕРТВО):
    -- =========================================================================
    -- Если у абилки в БД прописан путь к фабрике (например, cfg.projectile_factory = "#frostbolt_factory")
    if cfg.projectile_factory then
        -- Спелл требует летящего визуала (Фростболт)
        local spawn_pos = go.get_position(caster_unit.go_id)
        
        -- Рождаем Си-тело пули, скармливая свойствам чистокровные, легальные go_id из паспортов!
        -- Больше никаких строк и хэшей от строк! Движок Defold со свистом пропустит этот пакет!
        factory.create(
            cfg.projectile_factory, 
            spawn_pos, 
            nil, 
            {
                caster_go_id = caster_unit.go_id,
                target_go_id = target_unit.go_id,
                damage = final_damage,
                speed = cfg.projectile_speed or 500
            }
        )
        print(string.format("🚀 БЭКЕНД [Combat]: Снаряд [%s] запущен из %s в %s", 
            ability_id, caster_unit.uid, target_unit.uid))
    else
        M.apply_damage(caster_unit, target_unit, final_damage)
    end   
    -- =========================================================================
end

---🛬 ШЛЮЗ ИМПАКТА ПУЛИ: Принимает два Си-хэша тела со сцены и превращает их в RAM-паспорта
---@param caster_go_id hash Нативный Си-идентификатор атакующего (hash: [/player] или hash: [/instance7])
---@param target_go_id hash Нативный Си-идентификатор побитого моба (hash: [/instance8])
---@param damage number Рассчитанный урон
function M.apply_damage_by_go_id(caster_go_id, target_go_id, damage)
    -- 🚀 ПОЛНЫЙ КЛИНАП ЗАВИСИМОСТЕЙ:
    -- Нам глубоко насрать, кто это и где лежат их инстансы.
    -- Мы просто скармливаем Си-хэши напрямую в наш Фасад вселенной!
    -- Фасад сам зряче под капотом переведёт хэши в строки и вытащит Души!
    local caster_unit = game_state.get_entity_by_go_id(caster_go_id)
    local target_unit = game_state.get_entity_by_go_id(target_go_id)
    print("CASTER", caster_unit, "TARGET", target_unit)
    -- Наносим атомарный урон строго внутри ядра боёвки
    M.apply_damage(caster_unit, target_unit, damage)
end

---Универсальный атомарный метод нанесения любого урона во вселенной Meadows (WoW / BG3 канон)
---@param caster_unit UnitInstanceData Живой RAM-паспорт атакующего существа
---@param target_unit UnitInstanceData Живой RAM-паспорт жертвы, которая принимает удар
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
        target_unit.last_attacker_uid = caster_unit.uid
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
        if target_unit.is_dead then return end

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
        if target_unit.is_dead then return end

        -- 🦾 УЛЬТИМАТИВНЫЙ ПОЛИМОРФИЗМ: Скармливаем паспорт скелета в то же самое ядро!
        -- Метод вычтет ХП из RAM-карточки моба, а если здоровье упадет в ноль — сам взведет .is_dead = true!
        unit_logic.take_damage(raw_damage, target_unit)

        log_message = string.format("💥 БОЙ [combat_manager]: Юниту %s [%s] нанесено -%d урона! Живое ХП: %d/%d",
            target_unit.unit_id, target_unit.uid, raw_damage, target_unit.health, target_unit.max_health)

        -- Шлём бродкаст для рамки ховера и Nameplate целей, забирая go_id прямо из паспорта моба!
        broadcast.send("combat_events", {
            event = "unit_attacked",
            go_id = target_unit.go_id,
            uid = target_unit.uid
        })

        -- 🚀 РЕАКЦИЯ НА СМЕРТЬ/РАНЕНИЕ СИ-ТЕЛ НА СЦЕНЕ (СВЯЗКА С ДВИЖКОМ):
        -- Нам больше не нужны локаторы! Мы шлем Си-пакет напрямую по запеченному target_unit.go_id!
        if target_unit.go_id then
            if target_unit.is_dead then
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
