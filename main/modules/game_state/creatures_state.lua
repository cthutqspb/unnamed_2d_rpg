local creatures_db = require("main.modules.data.creatures_db")

---@class CreatureInstanceData
---@field name_key string
---@field creature_id string Строковый ID вида ("skeleton")
---@field uid string Уникальный строковый UID конкретного монстра
---@field level number Текущий уровень существа
---@field type string Тип существа ("undead", "beast", "humanoid")
---@field rank string Ранг сложности ("common", "rare", "elite")
---@field health number Текущее живое ХП в данный момент времени
---@field max_health number Рассчитанный лимит ХП с учетом уровня и ранга
---@field damage number Рассчитанный урон с учетом уровня
---@field speed number Скорость перемещения
---@field hitbox_size number
---@field attack_range_melee number
---@field ai_profile string
---@field saved_position vector3|nil
---@field is_in_combat boolean|nil
---@field ai_target vector3|nil

---@class RankModifiers
---@field hp_mult number       Множитель максимального здоровья
---@field dmg_mult number      Множитель базового урона
---@field resists table<string, number> Задел под резисты к стихиям (fire, frost и т.д.)
---@field bonus_abilities string[] Список дополнительных способностей, открываемых рангом

local M = {}

-- Главный реестр живых монстров в оперативной памяти [uid] = CreatureInstanceData
---@type table<string, CreatureInstanceData>
M.registry = {}

-- Быстрая телефонная книга связи физического go_id с бэкенд-уидом [go_id] = uid
---@type table<hash, string>
M.instances = {}

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

---Зарегистрировать заспавненного монстра в системе и рассчитать его характеристики
---@param go_id hash Движковый ID игрового объекта (/instance_skeleton_1)
---@param props { 
---   creature_id: string,
---   creature_uid: string,
---   level: number,
---   type: string,
---   rank: string,
--- }
---@return CreatureInstanceData|nil
function M.register(go_id, props)
    -- Распаковываем хэши из go.property обратно в строки для бэкенда (или подстраховываемся)
    local creature_id = props.creature_id
    local uid = props.creature_uid
    local creature_type = props.type
    local creature_rank = props.rank

    -- Ищем базовый генетический код в базе данных
    local cfg = creatures_db.get_creature(creature_id)
    if not cfg then
        print("ERROR: Попытка зарегистрировать неизвестного монстра:", creature_id)
        return nil
    end

    -- 🎯 МАТЕМАТИКА СКАЛИРОВАНИЯ: Рассчитываем параметры от уровня монстра
    local level_modifier_hp = math.pow(cfg.hp_growth, props.level - 1)
    local level_modifier_dmg = math.pow(cfg.damage_growth, props.level - 1)

    local max_hp = math.floor(cfg.base_hp * level_modifier_hp)
    local final_dmg = math.floor(cfg.base_damage * level_modifier_dmg)

     -- 2. 🎯 ВЫЗОВ НАШЕЙ НОВОЙ ФУНКЦИИ РАНГА:
    -- Получаем готовую, заармированную таблицу со всеми множителями и бонусами
    local rank_mods = compute_rank_modifiers(creature_rank)

    -- Применяем множители
    max_hp = math.floor(max_hp * rank_mods.hp_mult)
    final_dmg = math.floor(final_dmg * rank_mods.dmg_mult)

    -- Собираем живую структуру данных монстра
    ---@type CreatureInstanceData
    local instance_data = {
        name_key = cfg.name_key,
        creature_id = creature_id,
        uid = uid,
        level = props.level,
        type = creature_type,
        rank = creature_rank,
        max_health = max_hp,
        health = max_hp, -- на старте монстр полностью здоров
        damage = final_dmg,
        speed = cfg.base_speed,
        hitbox_size = cfg.hitbox_size,
        attack_range_melee = cfg.attack_range_melee,
        ai_profile = cfg.ai_profile or "aggressive_patrol"
    }

    -- Записываем в оперативную память реестров
    M.registry[uid] = instance_data
    M.instances[go_id] = uid

    -- print(string.format("БЭКЕНД МОНСТРОВ: Успешно зарегистрирован %s [%s] | Уровень: %d | ХП: %d/%d | Урон: %d",
    --     creature_id,
    --     uid,
    --     props.level,
    --     max_hp, max_hp,
    --     final_dmg
    --   ))

    return instance_data
end

---Удалить монстра из реестров (при смерти)
---@param go_id hash
function M.unregister(go_id)
    ---@type string|nil
    local uid = M.instances[go_id]
    if uid then
        M.registry[uid] = nil
        M.instances[go_id] = nil
    end
end

---Получить динамические данные монстра по его UID
---@param uid string
---@return CreatureInstanceData|nil
function M.get(uid)
    return M.registry[uid]
end

---Получить весь реестр живых монстров (для сохранения игры)
---@return table<string, CreatureInstanceData>
function M.get_all()
    return M.registry
end

function M.restore_all(data)
    M.registry = data or {}
end

function M.clear()
    M.registry = {}
    M.instances = {}
end

---Легкий бэкенд-мутатор для динамического обновления геймплейных данных монстра (WoW-канон)
---@param uid string Уникальный строковый UID существа ("c_1200_700")
---@param current_data table Новая таблица с измененными полями (saved_position, health и т.д.)
function M.update_data(uid, current_data)
    -- Проверяем, существует ли вообще паспорт этого моба в нашей оперативной памяти?
    -- (Посмотри, как у тебя называется главная таблица реестра: M.registry или M.db)
    if M.registry and M.registry[uid] then
        -- 🧱 СИММЕТРИЧНАЯ КЛАДКА ДАННЫХ (Data Merge):
        -- Мы не заменяем всю таблицу целиком, чтобы не сбить типы, а аккуратно 
        -- перезаписываем только то, что изменилось в creature.script перед выгрузкой!
        M.registry[uid].saved_position = current_data.saved_position

        -- Задел на будущее: если моб ранен — сохраняем текущее ХП, чтобы он не лечился за экраном!
        if current_data.health then
            M.registry[uid].health = current_data.health
        end

        print(string.format("💾 БЭКЕНД [update_data]: Записаны живые координаты для [%s] -> X: %d, Y: %d",
            uid, math.floor(current_data.saved_position.x), math.floor(current_data.saved_position.y)))
    else
        -- Если по какой-то причине паспорта нет (например, моба стерли), страхуем рантайм
        -- и создаем чистую запись, чтобы игра не вылетела в nil
        if M.registry then
            M.registry[uid] = current_data
        end
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
function M.is_creature_in_combat(uid)
    local creature_state = M.registry and M.registry[uid]
    if not creature_state then return false end

    -- Вся логика флагов ИИ и агро спрятана внутри синглтона стейта!
    -- Прямое, моментальное чтение полей без создания ООП-геттеров и метатаблиц!
    return creature_state.is_in_combat == true or creature_state.ai_target ~= nil
end

return M

