local game_state = require("main.modules.game_state.game_state")
local combat_manager = require("main.modules.system.combat_manager")

---@alias AIUnitState "IDLE" | "PATROL" | "CHASE" | "ATTACK" | "DEAD"
---@alias AIUnitProfile "aggressive_patrol" | "passive_coward"

---@class AIUnitContext : table Динамический контекст self из unit.script
---@field go_id hash Си-идентификатор игрового объекта существа
---@field uid string Уникальный строковый UID инстанса на карте для сейвов
---@field unit_id string Статический ID вида монстра из базы данных ("skeleton_warrior")
---@field spawn_position vector3 Изначальная точка дома, вокруг которой идет патруль
---@field ai_state AIUnitState Текущая фаза конечного автомата ИИ
---@field ai_timer number Универсальный таймер (время раздумий / откат атаки)
---@field ai_target vector3|nil Координаты целевой точки патрулирования в мире
---@field ai_is_patrolling boolean Флаг снижения боевой скорости в патруле
---@field agro_range number Изменяемый радиус обнаружения игрока (в пикселях)
---@field loose_range number Изменяемая дистанция потери игрока из вида
---@field hitbox_size number
---@field damage number
---@field attack_range number Итоговый рассчитанный радиус ближнего боя до пупка игрока
---@field primary_ability string

---@class AIProfileStrategy
---@field init fun(ctx: AIUnitContext) Инициализация параметров конкретной стратегии
---@field update fun(ctx: AIUnitContext, dt: number): vector3|nil Расчет кадра ИИ и возврат вектора направления

local M = {}

---@type table<AIUnitProfile, AIProfileStrategy>
local PROFILES = {}


---Рассчитать движение монстра обратно к его родной точке спавна (домой)
---@param ctx AIUnitContext Контекст self конкретного существа
---@param pos vector3 Текущие мировые координаты существа в кадре
---@return vector3|nil Вектор направления движения к дому или nil, если мы уже пришли
local function return_to_spawn(ctx, pos)
    -- Если у моба еще нет цели возвращения — жестко взводим домашние координаты
    if not ctx.ai_target then
        local home = ctx.spawn_position or go.get_position(ctx.go_id)
        ctx.ai_target = vmath.vector3(home.x, home.y, 0)
        ctx.ai_timer = 2.0 -- постоит подумает 2 секунды, когда дотопает до точки
    end

    local d = ctx.ai_target - pos
    if vmath.length(d) > 4 then
        ctx.ai_is_patrolling = true -- Снижаем скорость наполовину в unit.script, чтобы он шел вальяжно
        return vmath.normalize(d)
    else
        -- Успешно пришли в родное гнездо! Зануляем параметры и останавливаемся
        ctx.ai_target = nil
        ctx.ai_is_patrolling = false
        return nil
    end
end
-- =========================================================================
-- ПРОФИЛЬ: AGGRESSIVE_PATROL (Скелеты, Кабаны, Зомби, Драконы)
-- =========================================================================
PROFILES["aggressive_patrol"] = {
    init = function(ctx)
        ctx.ai_state = "IDLE"
        ctx.ai_timer = 1.0
        ctx.ai_target = nil
        ctx.ai_is_patrolling = false

        -- 1. Вытаскиваем характеристики ЭТОГО конкретного монстра из живого бэкенда Фасада
        local monster_data = game_state.get_entity_by_uid(ctx.uid)
        local monster_hitbox = monster_data and monster_data.hitbox_size or 64

        -- 2. 🦾 ААА-КАНОН РАДИУСА (ИСПРАВЛЕНО):
        -- Вместо чтения битых полей attack_range_melee из баз данных, ИИ знает:
        -- Ренж базовой автоатаки ближнего боя (melee_attack) во всей нашей вселенной 
        -- равен строго 12 пикселям! А базовый хитбокс Игрока-цели всегда равен 64 пикселям.
        local melee_ability_range = 12
        local player_hitbox = 64

        -- 🧱 УЛЬТИМАТИВНАЯ ФOРМУЛА БЛИЖНEГO БOЯ (Сумма радиусов + Ренж умения):
        -- Скелет:  32 (моб) + 32 (игрок) + 12 (абилка) = 76 пикселей до центра мага.
        -- Дракон:  64 (моб) + 32 (игрок) + 12 (абилка) = 108 пикселей до центра мага!
        -- Математика работает идеально, полиморфно и без единой строчки хардкода в базах!
        local monster_radius = monster_hitbox / 2
        local player_radius = player_hitbox / 2

        ctx.attack_range = monster_radius + player_radius + melee_ability_range
        ctx.primary_ability = monster_data and monster_data.abilities and monster_data.abilities[1] or "melee_attack"

        -- Скалирование зон видимости агро от габаритов туши (твой зрячий канон)
        if monster_hitbox >= 128 then
            ctx.agro_range = 450
            ctx.loose_range = 650
        else
            ctx.agro_range = 300
            ctx.loose_range = 450
        end

        print(string.format("🧠 ИИ ИНИЦ: [%s] | ID=%s | Габариты=%d | Авто-Ренж Ближнего Боя=%d",
            ctx.uid, ctx.unit_id, monster_hitbox, ctx.attack_range))
    end,

    update = function(ctx, dt)
        if ctx.ai_state == "DEAD" then
            return nil
        end

        -- Физические координаты самого монстра со сцены
        local position = go.get_position(ctx.go_id)

        -- 🦾 СИНХРОНИЗАЦИЯ СТЕЙТА С БЭКЕНДОМ (Канон BG3):
    -- Из Фасада забираем RAM-паспорт этого конкретного моба по его ctx.uid
        local unit = game_state.get_entity_by_uid(ctx.uid)
        -- Если перцепция секундой ранее всадила нам цель в паспорт — мозг на лету подхватывает её!
        if unit and unit.combat_target_uid then
            -- Проверяем: если мы ещё чиллили, а цель появилась — взводим погоню
            if ctx.ai_state == "IDLE" or ctx.ai_state == "PATROL" then
                ctx.ai_state = "CHASE"
                msg.post("main:/context_menu_layer#gui", "hide_menu")
            end
            ctx.ai_target_uid = unit.combat_target_uid -- Намертво привязали "player" в прицел ИИ!
        else
            -- Если в паспорте пусто (эвейд/сброс боя перцепцией) — гасим погоню
            if ctx.ai_state == "CHASE" or ctx.ai_state == "ATTACK" then
                ctx.ai_state = "IDLE"
                ctx.ai_target_uid = nil
                ctx.ai_target_pos = nil
            end
        end
        -- =========================================================================
        -- 🚀 СЛЕПОЙ ААА-ЗАХВАТ ЦЕЛИ (ВЫЖЖЕНО ИЗ КИШЕК CHARACTER_DATA):
        -- =========================================================================
        -- Мы просим Фасад game_state выдать нам живой паспорт Души строго по UID цели,
        -- который perception_manager запишет в поле ctx.ai_target_uid!
        local target_unit = ctx.ai_target_uid and game_state.get_entity_by_uid(ctx.ai_target_uid)

        -- Дефолтные буферы-заглушки для фазы пассивного покоя (IDLE/PATROL)
        local target_position = vmath.vector3(0, 0, 0)
        local distance_to_target = 999999 -- цель бесконечно далеко, пока мы спим

        -- 🎯 ДЕБАГ-СНАЙПЕР №1: Проверяем, видит ли ИИ моба прописанную менеджером цель!
        if ctx.ai_target_uid then
            print(string.format("🔍 [Debug AI Target Tick]: Моб [%s] в стейте [%s] видит цель-UID: [%s] | Паспорт в RAM найден = %s", 
                ctx.uid, ctx.ai_state, tostring(ctx.ai_target_uid), tostring(target_unit ~= nil)))
        end

        -- Если боевая цель реально существует в оперативной памяти RAM
        if target_unit and target_unit.saved_position then
            target_position = vmath.vector3(target_unit.saved_position.x, target_unit.saved_position.y, 1)
            distance_to_target = vmath.length(target_position - position)

            -- Проверяем смерть ЛЮБОЙ цели (игрока или другого моба) через её карточку
            if target_unit.is_dead then
                if ctx.ai_state == "CHASE" or ctx.ai_state == "ATTACK" then
                    print(string.format("💀 ИИ: [%s] Жертва [%s] мертва, расходимся по домам.", ctx.unit_id, ctx.ai_target_uid))
                    ctx.ai_state = "IDLE"
                    ctx.ai_target_uid = nil -- Очищаем боевой прицел
                    ctx.ai_target_pos = nil -- Очищаем векторную точку ходьбы

                    game_state.set_combat_state(ctx.uid, nil)
                end
                return return_to_spawn(ctx, position)
            end
        end

        -- Вектор направления движения на этот кадр
        local move_direction = nil

        -- =========================================================================
        -- СТEЙТ 1: ATTACK (ФАЗА БЛИЖНEГО БОЯ)
        -- =========================================================================
        if ctx.ai_state == "ATTACK" then
            if distance_to_target > ctx.attack_range + 12 then
                print(string.format("💥 ИИ: [%s] потерял дистанцию боя, возобновляю погоню!", ctx.unit_id))
                ctx.ai_state = "CHASE"
                move_direction = vmath.normalize(target_position - position)
            else
                ctx.ai_timer = ctx.ai_timer - dt
                if ctx.ai_timer <= 0 then
                    -- Пинаем боевой менеджер по оригинальным рельсам
                    combat_manager.execute_ability(
                        ctx.uid,
                        ctx.ai_target_uid,
                        ctx.primary_ability
                    )
                    ctx.ai_timer = (ctx.unit_id == "elder_green_dragon") and 2.0 or 1.5
                end
                move_direction = nil
            end

        -- =========================================================================
        -- СТEЙТ 2: CHASE (АГРЕССИВНАЯ ПОГОНЯ)
        -- =========================================================================
        elseif ctx.ai_state == "CHASE" then
            if distance_to_target > ctx.loose_range then
                print(string.format("🏃‍♂️ ИИ: [%s] потерял цель, возвращаюсь домой...", ctx.unit_id))
                ctx.ai_state = "IDLE"
                ctx.ai_target = nil

                game_state.set_combat_state(ctx.uid, nil)

                -- (Проверка: если мага больше никто на карте не бьет - в будущем сбросим комбат и магу)

                return return_to_spawn(ctx, position)

            elseif distance_to_target <= ctx.attack_range then
                print(string.format("⚔️ ИИ: [%s] догнал мага! Остановка для автоатаки!", ctx.unit_id))
                ctx.ai_state = "ATTACK"
                ctx.ai_timer = 0.3
                move_direction = nil
            else
                move_direction = vmath.normalize(target_position - position)
            end

        -- =========================================================================
        -- СТEЙТЫ ПОКОЯ: IDLE И PATROL
        -- =========================================================================
        else
            -- 🎯 ДЕБАГ-СНАЙПЕР №2: Проверяем, переключил ли perception_manager стейт моба из IDLE
            if ctx.ai_target_uid and (ctx.ai_state == "CHASE" or ctx.ai_state == "ATTACK") then
                print(string.format("⚡ [Debug AI Aggro Trigger]: Моб %s УСПЕШНО ЗААГРИЛСЯ! Стейт=%s | Цель=%s", 
                    ctx.uid, ctx.ai_state, ctx.ai_target_uid))
                
                -- Синхронизируем покадровый вектор погони на первом же тике агро!
                move_direction = vmath.normalize(target_position - position)
            
            elseif ctx.ai_state == "IDLE" then
                ctx.ai_timer = ctx.ai_timer - dt
                if ctx.ai_timer <= 0 then
                    local rx = ctx.spawn_position.x + math.random(-70, 70)
                    local ry = ctx.spawn_position.y + math.random(-70, 70)
                    
                    -- 🦾 ИСПОЛЬЗУЕМ AI_TARGET_POS КАК ЧИСТЫЙ ВЕКТОР ДЛЯ ПАТРУЛИРОВАНИЯ!
                    ctx.ai_target_pos = vmath.vector3(rx, ry, 0)
                    ctx.ai_state = "PATROL"
                end
                move_direction = nil
                
            elseif ctx.ai_state == "PATROL" and ctx.ai_target_pos then
                -- Считаем вектор до точки патрулирования strictly по ai_target_pos
                local d = ctx.ai_target_pos - position
                if vmath.length(d) > 4 then
                    ctx.ai_is_patrolling = true
                    move_direction = vmath.normalize(d)
                else
                    ctx.ai_state = "IDLE"
                    ctx.ai_timer = math.random(10, 30) / 10
                    ctx.ai_target_pos = nil
                    ctx.ai_is_patrolling = false
                    move_direction = nil
                end
            end
        end

        -- =========================================================================
        -- 🐺 АЛГОРИТМ SEPARATION: УЛЬТИМАТИВНЫЙ ОБХОД СОЮЗНИКОВ ПО КАСАТЕЛЬНОЙ
        -- =========================================================================
        if move_direction and vmath.length(move_direction) > 0 then
            local neighbor_count = 0
            local needs_hard_avoidance = false
            local avoidance_direction = vmath.vector3(0, 0, 0)

            -- 🎯 РAЗРЫВ ЛAПШИ: Бежим по инстансам через чистый Фасад game_state!
            local active_instances = game_state.get_active_unit_instances()

            for other_go_id, _ in pairs(active_instances) do
                if other_go_id ~= ctx.go_id then

                    local other_uid = active_instances[other_go_id]

                    -- 🎯 СИММЕТРИЧНЫЙ ВЫЗОВ: Достаем паспорт соседа через наш новый каскадный get_entity_by_uid!
                    local other_state = game_state.get_entity_by_uid(other_uid)

                    -- 🛡️ WoW-ФРАКЦИОННЫЙ ГВАРД ОКРУЖЕНИЯ (ИСПРАВЛЕНО):
                    -- 1. Если сосед мертв — мы его полностью игнорируем.
                    -- 2. Если сосед является ИГРОКОМ — мы его тоже игнорируем! 
                    -- Скелеты не будут пытаться "обойти" мага по касательной, они пойдут 
                    -- прямо на него напролом, нативно зажимая персонажа в плотное кольцо!
                    if other_state and (other_state.is_dead or other_state.is_player) then
                        -- LuaLS в Neovim прекрасно понимает этот легальный пропуск шага
                    else
                        -- 🧱 ВЕТКА ЖИВЫХ СОЮЗНИКОВ-МОБОВ (Твой оригинальный код обхода):
                        local other_position = go.get_position(other_go_id)
                        local distance_to_neighbor = vmath.length(other_position - position)

                        -- Пузырь личного пространства (сумма радиусов хитбоксов)
                        local other_hitbox = other_state and other_state.hitbox_size or 64
                        local min_distance = (ctx.hitbox_size / 2) + (other_hitbox / 2)

                        -- КРИТИЧЕСКАЯ ЗОНА СЛИПАНИЯ СУЩЕСТВ:
                        if distance_to_neighbor <= min_distance + 8 and distance_to_neighbor > 0 then
                            needs_hard_avoidance = true

                            -- Находим вектор от соседа к нам
                            local to_us = position - other_position

                            -- МАТЕМАТИКА КАСАТЕЛЬНОЙ (Тангенс обхода):
                            local tangent = vmath.vector3(-to_us.y, to_us.x, 0)
                            if vmath.dot(tangent, move_direction) < 0 then
                                tangent = vmath.vector3(to_us.y, -to_us.x, 0)
                            end

                            -- Копим силу обхода
                            avoidance_direction = avoidance_direction + vmath.normalize(tangent)
                            neighbor_count = neighbor_count + 1
                        end
                    end -- Конец гварда фракции/жизни соседа
                end
            end

            -- ПРИМЕНЕНИЕ ВЕКТОРА ОБХОДА (Твой оригинальный код):
            if needs_hard_avoidance and neighbor_count > 0 then
                avoidance_direction = vmath.normalize(avoidance_direction)

                ---@type vector3
                local blended_direction = move_direction * 0.3 + avoidance_direction * 0.7
                move_direction = vmath.normalize(blended_direction)
            end
        end

        return move_direction
    end
}

-- =========================================================================
-- ГЛАВНЫЙ ИНТЕРФЕЙС МЕНЕДЖЕРА ДЛЯ КОРМЛЕНИЯ СКРИПТОВ
-- =========================================================================

---Инициализировать профиль ИИ существа на основе его строки из базы данных
---@param profile_name AIUnitProfile Строковое имя профиля ("aggressive_patrol")
---@param ctx AIUnitContext Контекст (self) управляющего скрипта unit.script
function M.init(profile_name, ctx)
    ---@type AIProfileStrategy|nil
    local profile = PROFILES[profile_name]
    if profile then
        profile.init(ctx)
    end
end

---Обсчитать кадр ИИ и вернуть вектор направления движения для тела
---@param profile_name AIUnitProfile Строковое имя профиля ("aggressive_patrol")
---@param ctx AIUnitContext Контекст (self) управляющего скрипта unit.script
---@param dt number Дельта времени кадра
---@return vector3|nil Вектор направления движения (vmath.vector3) или nil
function M.update(profile_name, ctx, dt)
    ---@type AIProfileStrategy|nil
    local profile = PROFILES[profile_name]
    if profile then
        return profile.update(ctx, dt)
    end
    return nil
end

---Наглухо перевести ИИ существа в состояние смерти (WoW-канон)
---@param ctx AIUnitContext Контекст (self) управляющего скрипта unit.script
function M.disable(ctx)
    -- 1. 🎯 ПЕРЕКЛЮЧАЕМ КОНЕЧНЫЙ АВТОМАТ В СТEЙТ СMEРТИ:
    ctx.ai_state = "DEAD"
    -- 2. Полностью вычищаем все активные таймеры раздумий и откатов автоатак
    ctx.ai_timer = 0
    ctx.ai_target = nil
    ctx.ai_is_patrolling = false

    if game_state and game_state.set_combat_state then
        game_state.set_combat_state(ctx.uid, nil)
    end

    print(string.format("🤖 ИИ [disable]: Стейт ИИ для [%s] переведен в DEAD. Коллизии ИИ очищены.", tostring(ctx.uid)))
end

return M

