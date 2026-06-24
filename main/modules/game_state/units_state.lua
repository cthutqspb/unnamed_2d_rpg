local utils = require("main.modules.utils")
local units_db = require("main.modules.data.units_db")

---@class UnitInstanceData
---@field is_player boolean
---@field name_key string
---@field unit_id string Строковый ID вида ("skeleton")
---@field uid string Уникальный строковый UID конкретного монстра
---@field level number Текущий уровень существа
---@field experience number
---@field base_stats table<string, number>
---@field current_stats table<string, number>
---@field type string Тип существа ("undead", "beast", "humanoid")
---@field rank string Ранг сложности ("common", "rare", "elite")
---@field loot_table_id string|nil
---@field is_collected boolean
---@field health number Текущее живое ХП в данный момент времени
---@field max_health number Рассчитанный лимит ХП с учетом уровня и ранга
---@field mana number|nil
---@field max_mana number|nil
---@field auras table|nil
---@field damage number Рассчитанный урон с учетом уровня
---@field speed number Скорость перемещения
---@field hitbox_size number
---@field spellcast_range number
---@field ai_profile string
---@field saved_position vector3|nil
---@field is_in_combat boolean|nil
---@field is_dead boolean|nil
---@field is_invulnerable boolean|nil 🛡️ ОПЦИОНАЛЬНО: Флаг полной неуязвимости (вместо nil-ХП!)
---@field action_bars table<number, (ActionSlotData|nil)[]>|nil 🌟 ОПЦИОНАЛЬНО: Панели способностей
---@field ai_target vector3|nil

---@class UnitStatsTable
---@field strength number
---@field agility number
---@field intellect number
---@field stamina number

---@class ActionSlotData
---@field action_type "ability"|"item"|"empty" Тип действия в слоте
---@field action_id string|nil            Строковый ID из базы способностей или предметов

---@class RankModifiers
---@field health_multiplier number       Множитель максимального здоровья
---@field damage_multiplier number      Множитель базового урона
---@field resists table<string, number> Задел под резисты к стихиям (fire, frost и т.д.)
---@field bonus_abilities string[] Список дополнительных способностей, открываемых рангом

---@class UnitState
---@field registry table<string, UnitInstanceData>
---@field instances table<hash, string>
---@field is_loaded_from_save boolean
local M = {}

-- Главный реестр живых монстров в оперативной памяти [uid] = UnitInstanceData
---@type table<string, UnitInstanceData>
M.registry = {}

-- Быстрая телефонная книга связи физического go_id с бэкенд-уидом [go_id] = uid
---@type table<hash, string>
M.instances = {}

M.is_loaded_from_save = false

---Вычислить все геймплейные модификаторы и бонусы на основе ранга существа
---@param rank string Ранг сложности ("common", "rare", "elite", "boss")
---@return RankModifiers
local function compute_rank_modifiers(rank)
    -- Базовые дефолтные модификаторы для обычного моба (common)
    ---@type RankModifiers
    local modifiers = {
        health_multiplier = 1.0,
        damage_multiplier = 1.0,
        resists = { fire = 0, frost = 0, shadow = 0 },
        bonus_abilities = {}
    }

    if rank == "rare" then
        modifiers.health_multiplier = 1.5
        modifiers.damage_multiplier = 1.2
        -- Редкий моб получает легкую защиту
        modifiers.resists.fire = 10
        modifiers.resists.frost = 10
        -- table.insert(modifiers.bonus_abilities, "enrage") -- задел на будущее!

    elseif rank == "elite" then
        modifiers.health_multiplier = 3.0
        modifiers.damage_multiplier = 1.5
        modifiers.resists.fire = 25
        modifiers.resists.frost = 25
        modifiers.resists.shadow = 25
        -- table.insert(modifiers.bonus_abilities, "shield_slam")

    elseif rank == "boss" then
        modifiers.health_multiplier = 5.0
        modifiers.damage_multiplier = 2.0
        -- Босс ультимативно защищен от магии
        modifiers.resists.fire = 50
        modifiers.resists.frost = 50
        modifiers.resists.shadow = 50
        -- table.insert(modifiers.bonus_abilities, "aoe_fireball")
    end

    return modifiers
end

-- =========================================================================
-- СИСТЕМНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ РЕЕСТРОМ (Зеркало world_items_state)
-- =========================================================================

-- main/modules/game_state/units_state.lua

---Добавить юнита/игрока в глобальный реестр RAM (Стерильный WoW-канон)
---@param uid string Уникальный строковый UID ("player", "c_X_Y")
---@param props table Параметры спавна из Tiled или файла сохранения JSON
---@return table|nil
function M.add(uid, props)
    if M.registry and M.registry[uid] then
        return M.registry[uid]
    end

    local is_player_unit = (uid == "player" or props.is_player == true)

    -- 🦾 ЭТАЛОН 1: СБОРКА ИСХОДНЫХ ХАРАКТЕРИСТИК (БЕЗ ДУБЛИРОВАНИЯ)
    local source_stats = props.stats
    local source_abilities = props.abilities
    local monster_cfg = nil

    if not is_player_unit then
        monster_cfg = units_db.get_unit(props.unit_id)
        if not monster_cfg then
            print("ERROR: Попытка запечь паспорт неизвестного монстра:", props.unit_id)
            return nil
        end
        -- Если у моба нет кастомных стат (Новая Игра), берем его базовый расовый конфиг из базы
        source_stats = source_stats or monster_cfg.base_stats
        source_abilities = source_abilities or (monster_cfg and monster_cfg.abilities) or { "melee_attack" }
    else
        -- Фоллбек для игрока, если props пустой
        source_stats = source_stats or { strength = 10, agility = 10, intellect = 10, stamina = 10 }
    end

    -- Намертво изолируем базовые и текущие статы через твой DeepCopy модуль утилит
    local clean_stats = utils.deepcopy(source_stats)
    local clean_current_stats = utils.deepcopy(source_stats)
    local clean_source_abilities = utils.deepcopy(source_abilities)

    -- 🦾 ЭТАЛОН 2: ЛИНЕЙНЫЙ НАЛИТ ПАРАМЕТРОВ (Strictly по фракциям)
    local instance_data = {}

    if is_player_unit then
        -- 🌟 ВЕТКА ИГРОКА: Кристально плоские и понятные дефолты мага
        instance_data = {
            uid = "player",
            unit_id = props.unit_id or "player_mage",
            name_key = props.name_key or "class_mage",
            is_player = true,
            type = "humanoid",
            rank = "common",
            level = props.level or 1,
            experience = props.experience or 0,
            health = props.health or 100,
            max_health = props.max_health or 100,
            mana = props.mana or 50,
            max_mana = props.max_mana or 50,
            speed = 220,
            spellcast_range = 0,
            hitbox_size = props.hitbox_size or 64,
            loot_table_id = "empty",
            ai_profile = "none"
        }
    else
        -- 💀 ВЕТКА МОНСТРОВ: Рассчитываем динамическое скалирование ХП от уровня и ранга
        assert(monster_cfg, "Critical Error: monster_cfg is missing in monster spawn branch")

        local level_modifier = math.pow(monster_cfg.health_growth or 1, (props.level or 1) - 1)
        local calculated_max_health = math.floor((monster_cfg.base_health or 40) * level_modifier)

        if compute_rank_modifiers then
            local rank_mods = compute_rank_modifiers(props.rank or monster_cfg.default_rank)
            calculated_max_health = math.floor(calculated_max_health * rank_mods.health_multiplier)
        end

        instance_data = {
            uid = uid,
            unit_id = props.unit_id,
            name_key = props.name_key or monster_cfg.name_key,
            is_player = false,
            type = props.type or monster_cfg.type,
            rank = props.rank or monster_cfg.default_rank,
            level = props.level or 1,
            experience = props.experience or 0,

            -- Если грузим сейв — берем ХП из JSON (props), если Новая игра — берем расчетное!
            health = props.health or calculated_max_health,
            max_health = props.max_health or calculated_max_health,
            mana = props.mana or monster_cfg.base_mana,
            max_mana = props.max_mana or monster_cfg.base_mana,
            speed = monster_cfg.base_speed or 90,
            spellcast_range = monster_cfg.spellcast_range or 120,
            hitbox_size = props.hitbox_size or monster_cfg.hitbox_size,
            loot_table_id = props.loot_table_id or monster_cfg.loot_table_id,
            ai_profile = monster_cfg.ai_profile or "aggressive_patrol"
        }
    end

    -- 🦾 ЭТАЛОН 3: СКЛЕЙКА ОБЩИХ СИСТЕМНЫХ ПОЛЕЙ ЮНИТА
    instance_data.is_collected = (props.is_collected == true)
    instance_data.is_dead = (props.is_dead == true)
    instance_data.saved_position = props.saved_position or vmath.vector3(0, 0, 1.0)
    instance_data.action_bars = props.action_bars or {}
    -- Привязываем наши изолированные таблицы статов DeepCopy
    instance_data.stats = clean_stats
    instance_data.current_stats = clean_current_stats
    instance_data.abilities = clean_source_abilities

    -- Записываем готовую Душу Юнита в Single Source of Truth реестра RAM
    M.registry[uid] = instance_data
    return instance_data
end

---Связать физический Си-хэш go_id с бэкенд-уидом (MVC-Инкапсуляция!)
---@param go_id hash Движковый хэш объекта
---@param uid string Чистая строковая переменная UID
function M.register(go_id, uid)
    M.instances[go_id] = uid
end

---Разорвать связь между физическим объектом и реестром инстансов
---@param go_id hash
function M.unregister(go_id)
    M.instances[go_id] = nil
end

---Лутаем САМО ТЕЛО (WoW/BG3 канон)
---@param uid string Чистая строка UID
function M.remove(uid)
    if M.registry and M.registry[uid] then
        -- 🎯 ФИКС: Душа вечно живет в памяти, но получает метку сбора!
        M.registry[uid].is_collected = true
        print("💾 БЭКЕНД: Душа существа [" .. uid .. "] запечатана флагом is_collected!")
    else
        print("🚨 БЭКЕНД: Ошибка удаления! Ключ [" .. tostring(uid) .. "] не найден в registry!")
    end
end


---@param uid string Уникальный строковый идентификатор ("player" или "c_X_Y")
---@return UnitInstanceData|nil Возвращает таблицу живого паспорта юнита из RAM
function M.get_unit_by_uid(uid)
    if M.registry and M.registry[uid] then
        return M.registry[uid]
    end
    return nil
end

---Проверить, существует ли Душа монстра в глобальной памяти бэкенда
---@param uid string
---@return boolean
function M.exists(uid)
    return M.registry[uid] ~= nil
end

---Дополнительный быстрый метод-вопрос для скриптов
---@param uid string
---@return boolean
function M.is_unit_collected(uid)
    if M.registry and M.registry[uid] then
        return M.registry[uid].is_collected == true
    end
    return false
end

---Получить динамические данные монстра по его UID
---@param uid string
---@return UnitInstanceData|nil
function M.get(uid)
    return M.registry[uid]
end

---Получить весь реестр живых монстров (для сохранения игры)
---@return table<string, UnitInstanceData>
function M.get_all()
    return M.registry
end

---Раздача прилетевших из JSON данных обратно в оперативную память Lua монстров
---@param data table Таблица реестра монстров из файла сохранения
function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true
     print("🔬 [units_state restore_all] ДАННЫЕ ИЗ СЕЙВА:")
    -- 🎯 ЧИСТОКРОВНАЯ РЕГЕНЕРАЦИЯ ВЕКТОРОВ ПРИ ЗАГРУЗКЕ СЕЙВА:
    -- Пробегаем по всем восстановленным паспортам монстров в RAM.
    -- Кто превратил вектор в плоскую таблицу для сейва — тот сам возвращает его назад!
    for uid, unit_data in pairs(M.registry) do
        local saved_pos = unit_data.saved_position
         print(string.format("🔬   UID: %s | Жив: %s | Позиция в сейве: X=%s, Y=%s",
            uid, tostring(not unit_data.is_dead),
            tostring(saved_pos and saved_pos.x), tostring(saved_pos and saved_pos.y)))
        -- Если позиция прилетела из JSON-файла как плоская таблица {x, y, z}
        if saved_pos and type(saved_pos) == "table" then
            -- 💥 МЫ НА ЛЕТУ ВОЗВРАЩАЕМ ЕЙ СТАТУС ВЕКТОРА DEFOLD!
            -- Мы берём сохранённый .z без всякого хардкода! У трупа там нативно 
            -- восстановится честный слой 0.9, а у живого моба — слой 1.0!
            unit_data.saved_position = vmath.vector3(saved_pos.x, saved_pos.y, saved_pos.z or 1.0)
        end
    end

    print("💾 БЭКЕНД [units_state]: Все JSON-координаты монстров успешно переведены в Си-векторы vmath.vector3!")
end

function M.clear()
    M.registry = {}
    M.instances = {}
    M.is_loaded_from_save = false
end

---Легкий бэкенд-мутатор для динамического обновления геймплейных данных монстра (WoW-канон)
---@param uid string Уникальный строковый UID существа ("c_1200_700")
---@param current_data table Новая таблица с измененными полями (saved_position, health и т.д.)
function M.update_data(uid, current_data)
    -- Мы работаем строго и только если паспорт моба реально существует в памяти RAM!
    if M.registry and M.registry[uid] then
        -- 🧱 СИММЕТРИЧНАЯ КЛАДКА ДАННЫХ (Data Merge):
        -- Мы аккуратно перезаписываем только то, что реально прилетело, защищая типы!
        if current_data.saved_position then
            local live_pos = current_data.saved_position

            -- 🛡️ ПУЛЕНЕПРОБИВАЕМЫЙ ГВАРД ОКРУГЛЕНИЯ ПИКСЕЛЕЙ (X и Y):
            -- Мы принудительно округляем покадровые X и Y до ближайшего целого числа.
            -- Это полностью уничтожает дробные хвосты (вроде .4239), которые ломают 
            -- математику генерации UID и чертежей в спавнере!
            -- При этом ось Z мы ВООБЩЕ НЕ ТРОГАЕМ (работает как работала)!
            M.registry[uid].saved_position = vmath.vector3(
                math.floor(live_pos.x + 0.5),
                math.floor(live_pos.y + 0.5),
                live_pos.z -- Z оставляем в покое, создатели движка не идиоты!
            )
        end

        if current_data.health then
            M.registry[uid].health = current_data.health
        end

        if current_data.is_dead ~= nil then
            M.registry[uid].is_dead = current_data.is_dead
        end

        -- 🎯 ДОПОЛНИТЕЛЬНЫЙ ГВАРД ПАСПОРТА:
        -- Если моб умер, принудительно страхуем здоровье на жесткий ноль,
        -- чтобы оно никогда фантомно не сбросилось в nil!
        if current_data.is_dead == true then
            M.registry[uid].health = 0
        end
    else
        -- ❌ СТИРАЕМ ОТСЮДА НАФИГ СЛEПОE ЗА ТИРAНИE M.registry[uid] = current_data!
        -- Интерфейс и ИИ больше никогда не потеряют паспортные данные моба!
        print("🚨 БЭКЕНД ГВАРД: Предотвращена попытка затереть паспорт моба пустышкой координат:", uid)
    end
end

---Установить или снять боевой режим для существа (Инкапсулированный WoW-канон)
---@param uid string Уникальный строковый UID моба
---@param is_in_combat boolean Флаг входа/выхода из боя
function M.set_combat(uid, is_in_combat)
    if M.registry and M.registry[uid] then
        M.registry[uid].is_in_combat = is_in_combat

        -- Задел на будущее: тут можно кидать бродкаст "моб_вошел_в_бой" для HUD
        if is_in_combat then
            print("💾 БЭКЕНД: Душа [" .. uid .. "] официально перешла в БОЕВОЙ РЕЖИМ!")
        else
            print("💾 БЭКЕНД: Душа [" .. uid .. "] вышла из боя, покой восстановлен.")
        end
    end
end

---Проверить, находится ли Душа моба в боевом состоянии (WoW-канон)
---@param uid string
---@return boolean
function M.is_unit_in_combat(uid)
    local unit_state = M.registry and M.registry[uid]
    if not unit_state then return false end

    -- Вся логика флагов ИИ и агро спрятана внутри синглтона стейта!
    -- Прямое, моментальное чтение полей без создания ООП-геттеров и метатаблиц!
    return unit_state.is_in_combat == true or unit_state.ai_target ~= nil
end

-- =========================================================================
-- 🦾 ЛЕГКИЕ БОЕВЫЕ МУТАТОРЫ (WoW-канон: Только RAM и Бродкаст)
-- =========================================================================

---Установить точное значение здоровья монстра в оперативной памяти
---@param uid string Уникальный строковый UID существа
---@param new_health number Финальное высчитанное значение ХП
function M.set_health(uid, new_health)
    if M.registry and M.registry[uid] then
        -- Жесткое атомарное присвоение
        M.registry[uid].health = math.max(0, new_health)
    end
end

---Установить точное значение маны/энергии монстра
---@param uid string Уникальный строковый UID существа
---@param new_mana number Финальное значение маны
function M.set_mana(uid, new_mana)
    if M.registry and M.registry[uid] then
        M.registry[uid].mana = math.max(0, new_mana)
    end
end

---Обновить состояние аур (баффов/дебаффов) монстра
---@param uid string Уникальный строковый UID существа
---@param auras_table table Актуальный массив аур существа
function M.set_auras(uid, auras_table)
    if M.registry and M.registry[uid] then
        M.registry[uid].auras = auras_table or {}
    end
end

return M

