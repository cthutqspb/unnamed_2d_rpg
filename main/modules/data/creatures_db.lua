---@class CreatureConfig
---@field name_key string Локализационный ключ имени существа
---@field base_hp number Базовое здоровье на 1 уровне
---@field hp_growth number Коэффициент роста ХП за каждый уровень (например, +15% это 1.15)
---@field base_damage number Базовый урон на 1 уровне
---@field damage_growth number Коэффициент роста урона за уровень
---@field base_speed number Базовая скорость перемещения в пикселях
---@field hitbox_size number
---@field attack_range_melee number
---@field animation string Имя дефолтной анимации покоя в атласе
---@field texture string Имя графического атласа/тайлсорса
---@field id? string Строковый ID существа для бэкенда
---@field ai_profile string

local M = {}

---@type table<string, CreatureConfig>
M.creatures = {
     ["skeleton_warrior"] = {
        name_key = "creature_skeleton_warrior_name",
        type = "undead",
        base_hp = 40,
        hp_growth = 1.12,     -- +12% здоровья за уровень
        base_damage = 3,
        damage_growth = 1.06, -- +6% урона за уровень
        base_speed = 90,      -- скелеты ходят чуть медленнее игрока
        hitbox_size = 64,
        attack_range_melee = 8,
        animation = "skeleton_warrior",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol"
    },
    ["dire_boar"] = {
        name_key = "creature_dire_boar_name",
        type = "beast",
        base_hp = 50,         -- ХП на 1 уровне
        hp_growth = 1.15,     -- +15% ХП за каждый уровень
        base_damage = 4,      -- урон на 1 уровне
        damage_growth = 1.08, -- +8% урона за уровень
        base_speed = 120,     -- базовая скорость бега
        hitbox_size = 64,
        attack_range_melee = 8,
        animation = "boar_idle",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol"
    },
    ["elder_green_dragon"] = {
        name_key = "creature_elder_green_dragon_name",
        type = "dragon",
        base_hp = 420,
        hp_growth = 1.12,     -- +12% здоровья за уровень
        base_damage = 18,
        damage_growth = 1.2, -- +6% урона за уровень
        base_speed = 175,      -- скелеты ходят чуть медленнее игрока
        hitbox_size = 128,
        attack_range_melee = 16,
        spellcast_range = 120,
        animation = "elder_green_dragon",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol"
    },

}

-- Быстрый кэш хэшированных ключей для мгновенного поиска из go.property
---@type any
local creatures_by_hash = {}

for id_str, data in pairs(M.creatures) do
    data.id = id_str
    creatures_by_hash[hash(id_str)] = data
end

---Универсальная быстрая функция получения статического конфига существа
---@param id any Идентификатор существа (хэш Defold или чистая Lua-строка)
---@return CreatureConfig|nil data Ссылка на статический конфиг или nil
function M.get_creature(id)
    -- Если прилетел хэш (из go.property в creature.script), мгновенно забираем из кэша. 
    -- Если прилетела строка (из сумок или логов), забираем из M.creatures.
    return creatures_by_hash[id] or M.creatures[id]
end

return M
