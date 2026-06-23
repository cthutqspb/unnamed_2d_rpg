local units_db = require("main.modules.data.units_db")

---@class UnitInstanceData
---@field is_player boolean
---@field name_key string
---@field unit_id string Строковый ID вида ("skeleton")
---@field uid string Уникальный строковый UID конкретного монстра
---@field level number Текущий уровень существа
---@field stats table<string, number>
---@field current_stats table<string, number>
---@field type string Тип существа ("undead", "beast", "humanoid")
---@field rank string Ранг сложности ("common", "rare", "elite")
---@field loot_table_id string
---@field is_collected boolean
---@field health number Текущее живое ХП в данный момент времени
---@field max_health number Рассчитанный лимит ХП с учетом уровня и ранга
---@field mana number|nil
---@field max_mana number|nil
---@field damage number Рассчитанный урон с учетом уровня
---@field speed number Скорость перемещения
---@field hitbox_size number
---@field attack_range_melee number
---@field ai_profile string
---@field saved_position vector3|nil
---@field is_in_combat boolean|nil
---@field is_dead boolean|nil
---@field is_invulnerable boolean|nil 🛡️ ОПЦИОНАЛЬНО: Флаг полной неуязвимости (вместо nil-ХП!)
---@field action_bars table<number, (ActionSlotData|nil)[]>|nil 🌟 ОПЦИОНАЛЬНО: Панели способностей
---@field ai_target vector3|nil

---@class RankModifiers
---@field hp_mult number       Множитель максимального здоровья
---@field dmg_mult number      Множитель базового урона
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
        hp_mult = 1.0,
        dmg_mult = 1.0,
        resists = { fire = 0, frost = 0, shadow = 0 },
        bonus_abilities = {}
    }

    if rank == "rare" then
        modifiers.hp_mult = 1.5
        modifiers.dmg_mult = 1.2
        -- Редкий моб получает легкую защиту
        modifiers.resists.fire = 10
        modifiers.resists.frost = 10
        -- table.insert(modifiers.bonus_abilities, "enrage") -- задел на будущее!

    elseif rank == "elite" then
        modifiers.hp_mult = 3.0
        modifiers.dmg_mult = 1.5
        modifiers.resists.fire = 25
        modifiers.resists.frost = 25
        modifiers.resists.shadow = 25
        -- table.insert(modifiers.bonus_abilities, "shield_slam")

    elseif rank == "boss" then
        modifiers.hp_mult = 5.0
        modifiers.dmg_mult = 2.0
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

---Добавить нового монстра в глобальный реестр (Вызывается СТРОГО в Bake Mode)
---@param uid string Уникальный строковый UID моба
---@param props table Таблица изначальных параметров из чертежа редактора
---@return table|nil
function M.add(uid, props)
    if M.registry and M.registry[uid] then
        print("🛡️ БЭКЕНД: Паспорт моба уже существует в RAM. Защита спасла сейв от затирания для:", uid)
        return M.registry[uid]
    end

    -- local cfg = units_db.get_unit(props.unit_id)
    -- if not cfg then
    --     print("ERROR: Попытка запечь паспорт неизвестного монстра:", props.unit_id)
    --     return nil
    -- end

    -- 🎯 WoW-ГВАРД ИСКЛЮЧЕНИЯ ИГРОКА (ИСПРАВЛЕНО):
    -- Если создается Юнит игрока, мы полностью пропускаем проверку по базе монстров units_db, 
    -- так как у игрока свои собственные кастомные статы, расы и классы!
    local is_player_unit = (uid == "player" or props.is_player == true)

    if not is_player_unit then
        -- Ветка монстров: Жестко проверяем шаблон по статичной базе units_db
        local cfg = units_db.get_unit(props.unit_id)
        if not cfg then
            print("ERROR: Попытка запечь паспорт неизвестного монстра:", props.unit_id)
            return nil
        end
        
        -- ... твой зеркальный код расчета ХП и Дамага монстра от уровня и ранга (level_modifier) ...
        -- ... (max_hp = math.floor, final_dmg = math.floor) ...
    end

    -- Математика скалирования характеристик от уровня
    -- local level_modifier_hp = math.pow(cfg.hp_growth, props.level - 1)
    -- local level_modifier_dmg = math.pow(cfg.damage_growth, props.level - 1)
    --
    -- local max_hp = math.floor(cfg.base_hp * level_modifier_hp)
    -- local final_dmg = math.floor(cfg.base_damage * level_modifier_dmg)
    --
    -- -- Расчет множителей ранга существа
    -- local rank_mods = compute_rank_modifiers(props.rank)
    -- max_hp = math.floor(max_hp * rank_mods.hp_mult)
    -- final_dmg = math.floor(final_dmg * rank_mods.dmg_mult)

    local instance_data = {
        uid = uid,
        unit_id = props.unit_id or "unknown",
        name_key = props.name_key or "unknown_name",
        is_player = (props.is_player == true),
        type = props.type or "undead",
        rank = props.rank,
        level = props.level or 1,
        experience = props.experience or 0,
        health = props.health or 100,
        max_health = props.max_health or 100,
        mana = props.mana,
        max_mana = props.max_mana,
        --damage = final_dmg,
        --speed = cfg.base_speed,
        hitbox_size = props.hitbox_size or 64,
        loot_table_id = props.loot_table_id,
        is_collected = false,
        --attack_range_melee = cfg.attack_range_melee,
        --ai_profile = cfg.ai_profile or "aggressive_patrol",
        stats = props.stats or { strength = 10, agility = 10, intellect = 10, stamina = 10 },
        current_stats = props.current_stats or { strength = 10, agility = 10, intellect = 10, stamina = 10 },
        saved_position = props.saved_position or vmath.vector3(0, 0, 1.0),
        is_dead = (props.is_dead == true),
        action_bars = props.action_bars or {}
    }

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

