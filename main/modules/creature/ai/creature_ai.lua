local character_data = require("main.modules.character.character_data")
local creatures_state = require("main.modules.game_state.creatures_state")
local combat_manager = require("main.modules.system.combat_manager")

---@alias AICreatureState "IDLE" | "PATROL" | "CHASE" | "ATTACK" | "DEAD"
---@alias AICreatureProfile "aggressive_patrol" | "passive_coward"

---@class AICreatureContext : table Динамический контекст self из creature.script
---@field go_id hash Си-идентификатор игрового объекта существа
---@field uid string Уникальный строковый UID инстанса на карте для сейвов
---@field creature_id string Статический ID вида монстра из базы данных ("skeleton_warrior")
---@field spawn_position vector3 Изначальная точка дома, вокруг которой идет патруль
---@field ai_state AICreatureState Текущая фаза конечного автомата ИИ
---@field ai_timer number Универсальный таймер (время раздумий / откат атаки)
---@field ai_target vector3|nil Координаты целевой точки патрулирования в мире
---@field ai_is_patrolling boolean Флаг снижения боевой скорости в патруле
---@field agro_range number Изменяемый радиус обнаружения игрока (в пикселях)
---@field loose_range number Изменяемая дистанция потери игрока из вида
---@field hitbox_size number
---@field damage number
---@field attack_range number Итоговый рассчитанный радиус ближнего боя до пупка игрока

---@class AIProfileStrategy
---@field init fun(ctx: AICreatureContext) Инициализация параметров конкретной стратегии
---@field update fun(ctx: AICreatureContext, dt: number): vector3|nil Расчет кадра ИИ и возврат вектора направления

local M = {}

---@type table<AICreatureProfile, AIProfileStrategy>
local PROFILES = {}


---Рассчитать движение монстра обратно к его родной точке спавна (домой)
---@param ctx AICreatureContext Контекст self конкретного существа
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
        ctx.ai_is_patrolling = true -- Снижаем скорость наполовину в creature.script, чтобы он шел вальяжно
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

        -- 1. Вытаскиваем характеристики монстра из живого бэкенда
        local creature_instance_data = creatures_state.get(ctx.uid)
        local monster_hitbox = creature_instance_data and creature_instance_data.hitbox_size or 64
        local monster_reach = creature_instance_data and creature_instance_data.attack_range_melee or 8
        -- 🎯 ВЫТАСКИВАЕM ДИНАМИЧЕСКИЙ УРОН:
        -- Бэкенд за секунду рассчитал урон с учётом уровня и рангов common/rare/elite/boss!
        ctx.damage = creature_instance_data and creature_instance_data.damage or 3
        -- 2. 🎯 ВЫТАСКИВАEМ ГАБАРИТЫ ИГРOКА ИЗ СИНГЛТOНА:
        -- Читаем размер хитбокса мага (64 пикселя) напрямую из character_data
        local player_hitbox = character_data.player.hitbox_size or 64

        -- 3. 🧱 УЛЬТИМАТИВНАЯ ААА-ФOРМУЛА БЛИЖНEГO БOЯ (Сумма радиусов + Досягаемость):
        -- Скелет:  32 (моб) + 32 (игрок) + 8  (оружие) = 72 пикселя до центра игрока.
        -- Дракон:  64 (моб) + 32 (игрок) + 16 (оружие) = 112 пикселей до центра игрока!
        local monster_radius = monster_hitbox / 2
        local player_radius = player_hitbox / 2

        ctx.attack_range = monster_radius + player_radius + monster_reach

        -- Скалирование зон видимости (оставляем твой зрячий канон)
        if monster_hitbox >= 128 then
            ctx.agro_range = 450
            ctx.loose_range = 650
        else
            ctx.agro_range = 300
            ctx.loose_range = 450
        end

        print(string.format("🧠 ИИ ИНИЦ: [%s] | ID=%s | Урон=%d | Дист.Атаки=%d",
            ctx.uid, ctx.creature_id, ctx.damage, ctx.attack_range))
    end,

    update = function(ctx, dt)
        if ctx.ai_state == "DEAD" then
            return nil
        end

        local player_position_data = character_data.player.last_position
        if not player_position_data then return nil end

        local position = go.get_position(ctx.go_id)

        if character_data.player.is_dead then
            if ctx.ai_state == "CHASE" or ctx.ai_state == "ATTACK" then
                print(string.format("💀 ИИ: [%s] Жертва мертва, расходимся по домам.", ctx.creature_id))
                ctx.ai_state = "IDLE"
                ctx.ai_target = nil -- Сбрасываем старую цель, хелпер сам пересчитает дом от spawn_pos

                creatures_state.set_combat(ctx.uid, false)
            end
            -- Просто просим хелпер вести нас к спавну
            return return_to_spawn(ctx, position)
        end

        local player_position = vmath.vector3(player_position_data.x, player_position_data.y, 1)
        local distance_to_player = vmath.length(player_position - position)

        -- 🎯 СИ-ЛОКАЛЬНЫЙ ВЕКТОР НАПРАВЛЕНИЯ (Сюда мозг запишет желаемый шаг)
        local move_direction = nil

        -- =========================================================================
        -- СТEЙТ 1: ATTACK (ФАЗА БЛИЖНEГО БОЯ)
        -- =========================================================================
        if ctx.ai_state == "ATTACK" then
            if distance_to_player > ctx.attack_range + 12 then
                print(string.format("💥 ИИ: [%s] потерял дистанцию боя, возобновляю погоню!", ctx.creature_id))
                ctx.ai_state = "CHASE"
                move_direction = vmath.normalize(player_position - position)
            else
                -- 🎯 ТАЙМЕР АВТОАТАК: Уменьшаем внутреннее ГКД отката удара
                ctx.ai_timer = ctx.ai_timer - dt
                if ctx.ai_timer <= 0 then
                    -- ⚔️ ПИНАЕМ БОЕВОЙ МЕНЕДЖЕР:
                    -- Передаем: КТО бьет (ctx.go_id), КОГО бьет ("/player") и СКОЛЬКО (ctx.damage)
                    combat_manager.apply_damage(ctx.go_id, "/player", ctx.damage)

                    -- Задаем индивидуальную скорость атаки: Дракон-Босс кусает раз в 2.0 сек, Скелет — в 1.5 сек
                    ctx.ai_timer = (ctx.creature_id == "elder_green_dragon") and 2.0 or 1.5
                end
                move_direction = nil -- Тело стоит как влитое, не толкаясь коллизиями!
            end

        -- =========================================================================
        -- СТEЙТ 2: CHASE (АГРЕССИВНАЯ ПОГОНЯ)
        -- =========================================================================
        elseif ctx.ai_state == "CHASE" then
            if distance_to_player > ctx.loose_range then
                -- 🎯 ВТОРОЙ ВЫЗОВ ХEЛПEРA: Игрок просто убежал из зоны преследования!
                print(string.format("🏃‍♂️ ИИ: [%s] потерял цель, возвращаюсь домой...", ctx.creature_id))
                ctx.ai_state = "IDLE"
                ctx.ai_target = nil

                creatures_state.set_combat(ctx.uid, false)

                return return_to_spawn(ctx, position) -- Ювелирно топаем домой по этой же формуле!

            elseif distance_to_player <= ctx.attack_range then
                print(string.format("⚔️ ИИ: [%s] догнал мага! Остановка для автоатаки!", ctx.creature_id))
                ctx.ai_state = "ATTACK"
                ctx.ai_timer = 0.3
                move_direction = nil
            else
                move_direction = vmath.normalize(player_position - position)
            end

        -- =========================================================================
        -- СТEЙТЫ ПОКОЯ: IDLE И PATROL
        -- =========================================================================
        else
            if distance_to_player < ctx.agro_range then
                print(string.format("💀 ИИ: [%s] обнаружил нарушителя в Meadows! АГРO!", ctx.creature_id))
                ctx.ai_state = "CHASE"
                msg.post("main:/context_menu_layer#gui", "hide_menu")

                creatures_state.set_combat(ctx.uid, true)
                move_direction = vmath.normalize(player_position - position)
            elseif ctx.ai_state == "IDLE" then
                ctx.ai_timer = ctx.ai_timer - dt
                if ctx.ai_timer <= 0 then
                    local rx = ctx.spawn_position.x + math.random(-70, 70)
                    local ry = ctx.spawn_position.y + math.random(-70, 70)
                    ctx.ai_target = vmath.vector3(rx, ry, 0)
                    ctx.ai_state = "PATROL"
                end
                move_direction = nil
            elseif ctx.ai_state == "PATROL" and ctx.ai_target then
                local d = ctx.ai_target - position
                if vmath.length(d) > 4 then
                    ctx.ai_is_patrolling = true
                    move_direction = vmath.normalize(d)
                else
                    ctx.ai_state = "IDLE"
                    ctx.ai_timer = math.random(10, 30) / 10
                    ctx.ai_target = nil
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

            -- Флаг и вектор для жесткого маневра обхода по касательной
            local needs_hard_avoidance = false
            local avoidance_direction = vmath.vector3(0, 0, 0)

            for other_go_id, _ in pairs(creatures_state.instances) do
                if other_go_id ~= ctx.go_id then

                    -- 🎯 1. ВЫТАCКИВАЕМ СТЕЙТ СОСЕДА ИЗ БЭКЕНДА (Твой оригинальный зрячий MVC)
                    local other_uid = creatures_state.instances[other_go_id]
                    local other_state = creatures_state.get(other_uid)

                    -- 🎯 2. WoW-ГВАРД ОПТИМИЗАЦИИ (Короткое замыкание для мертвецов):
                    -- Если сосед мёртв — мы его наглухо игнорируем! 
                    -- Живые скелеты будут нативно проходить сквозь лежащий труп, 
                    -- не ломая строй и не тратя ресурсы процессора на расчёт расстояний!
                    if other_state and other_state.is_dead then
                        -- С Си-уровня Lua это просто означает "пропусти шаг и иди к следующему other_go_id"
                        -- (Заменяем пустую заглушку на легальный пропуск)

                    else
                        -- 🧱 ВЕТКА ЖИВЫХ СОЮЗНИКОВ (Твой оригинальный безупречный код обхода):
                        local other_position = go.get_position(other_go_id)
                        local distance_to_neighbor = vmath.length(other_position - position)

                        -- Пузырь личного пространства (берем честную сумму радиусов хитбоксов)
                        local other_hitbox = other_state and other_state.hitbox_size or 64
                        local min_distance = (ctx.hitbox_size / 2) + (other_hitbox / 2)

                        -- КРИТИЧЕСКАЯ ЗОНА СЛИПАНИЯ:
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
                    end -- Конец гварда жизни/смерти соседа
                end
            end

            -- ПРИМЕНЕНИЕ ВЕКТОРА ОБХОДА (Твой оригинальный код с тайпкастом для Neovim):
            if needs_hard_avoidance and neighbor_count > 0 then
                avoidance_direction = vmath.normalize(avoidance_direction)

                ---@type vector3
                local blended_direction = move_direction * 0.3 + avoidance_direction * 0.7
                move_direction = vmath.normalize(blended_direction)
            end
        end

        -- 🧱 Линтер теперь видит чистокровный vector3|nil и горит идеальным зеленым светом!
        return move_direction
    end
}

-- =========================================================================
-- ГЛАВНЫЙ ИНТЕРФЕЙС МЕНЕДЖЕРА ДЛЯ КОРМЛЕНИЯ СКРИПТОВ
-- =========================================================================

---Инициализировать профиль ИИ существа на основе его строки из базы данных
---@param profile_name AICreatureProfile Строковое имя профиля ("aggressive_patrol")
---@param ctx AICreatureContext Контекст (self) управляющего скрипта creature.script
function M.init(profile_name, ctx)
    ---@type AIProfileStrategy|nil
    local profile = PROFILES[profile_name]
    if profile then
        profile.init(ctx)
    end
end

---Обсчитать кадр ИИ и вернуть вектор направления движения для тела
---@param profile_name AICreatureProfile Строковое имя профиля ("aggressive_patrol")
---@param ctx AICreatureContext Контекст (self) управляющего скрипта creature.script
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
---@param ctx AICreatureContext Контекст (self) управляющего скрипта creature.script
function M.disable(ctx)
    -- 1. 🎯 ПЕРЕКЛЮЧАЕМ КОНЕЧНЫЙ АВТОМАТ В СТEЙТ СMEРТИ:
    ctx.ai_state = "DEAD"
    
    -- 2. Полностью вычищаем все активные таймеры раздумий и откатов автоатак
    ctx.ai_timer = 0
    ctx.ai_target = nil
    ctx.ai_is_patrolling = false

    print(string.format("🤖 ИИ [disable]: Стейт ИИ для [%s] переведен в DEAD. Коллизии ИИ очищены.", tostring(ctx.uid)))
end

return M

