local creatures_db = require("main.modules.data.creatures_db")

---@class CreatureInstanceData
---@field creature_id string|nil Строковый ID вида ("skeleton")
---@field uid string Уникальный строковый UID конкретного монстра
---@field level number Текущий уровень существа
---@field type string Тип существа ("undead", "beast", "humanoid")
---@field rank string Ранг сложности ("common", "rare", "elite")
---@field health number Текущее живое ХП в данный момент времени
---@field max_health number Рассчитанный лимит ХП с учетом уровня и ранга
---@field damage number Рассчитанный урон с учетом уровня
---@field speed number Скорость перемещения

local M = {}

-- Главный реестр живых монстров в оперативной памяти [uid] = CreatureInstanceData
---@type table<string, CreatureInstanceData>
M.registry = {}

-- Быстрая телефонная книга связи физического go_id с бэкенд-уидом [go_id] = uid
---@type table<hash, string>
M.instances = {}

---Зарегистрировать заспавненного монстра в системе и рассчитать его характеристики
---@param go_id hash Движковый ID игрового объекта (/instance_skeleton_1)
---@param props { 
---   creature_id: hash|string,
---   creature_uid: string,
---   level: number,
---   type: string,
---   rank: string,
--- }  🚩 ФИКС ТИПОВ: Разрешаем строку через hash|string!
---@return CreatureInstanceData|nil
function M.register(go_id, props)
    print('CREATURE ID', props.creature_id)
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

    if creature_rank == "rare" then
        max_hp = math.floor(max_hp * 1.5)
        final_dmg = math.floor(final_dmg * 1.2)
    elseif creature_rank == "elite" then
        max_hp = math.floor(max_hp * 3.0)
        final_dmg = math.floor(final_dmg * 1.5)
    elseif creature_rank == "boss" then
        max_hp = math.floor(max_hp * 5.0) -- Босс жирнее в 5 раз!
        final_dmg = math.floor(final_dmg * 2.0)
    end
    -- Собираем живую структуру данных монстра
    ---@type CreatureInstanceData
    local instance_data = {
        creature_id = creature_id,
        uid = uid,
        level = props.level,
        type = creature_type,
        rank = creature_rank,
        max_health = max_hp,
        health = max_hp, -- на старте монстр полностью здоров
        damage = final_dmg,
        speed = cfg.base_speed
    }

    -- Записываем в оперативную память реестров
    M.registry[uid] = instance_data
    M.instances[go_id] = uid

    print(string.format("БЭКЕНД МОНСТРОВ: Успешно зарегистрирован %s [%s] | Уровень: %d | ХП: %d/%d | Урон: %d",
        creature_id, uid, props.level, max_hp, max_hp, final_dmg))

    return instance_data
end

---Удалить монстра из реестров (при смерти)
---@param go_id hash
function M.unregister(go_id)
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

return M

