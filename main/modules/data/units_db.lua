---@class UnitConfig
---@field type string  Нежить, дракон, животное, конструкция, потустороннее, демон, бог
---@field unit_class table <string, boolean> Маг, жрец, воин, разбойник
---@field base_stats UnitStatsTable
---@field race string|nil Человек, огр, гоблин, дварф, эльф
---@field name_key string Локализационный ключ имени существа
---@field base_health number Базовое здоровье на 1 уровне
---@field base_mana number|nil
---@field health_growth number Коэффициент роста ХП за каждый уровень (например, +15% это 1.15)
---@field damage_growth number Коэффициент роста урона за уровень
---@field base_speed number Базовая скорость перемещения в пикселях
---@field hitbox_size number
---@field spellcast_range number|nil
---@field animation string Имя дефолтной анимации покоя в атласе
---@field texture string Имя графического атласа/тайлсорса
---@field id? string Строковый ID существа для бэкенда
---@field ai_profile string
---@field base_aggro_radius number
---@field faction string
---@field loot_table_id string|nil
---@field default_rank string
---@field abilities table<string>

local M = {}

---@type table<string, UnitConfig>
M.units = {
     ["skeleton_warrior"] = {
        name_key = "unit_skeleton_warrior_name",
        race = "elf",
        type = "skeleton",
        unit_class = {
            warrior = true
        },
        base_stats = {
            strength = 14,
            agility = 12,
            intellect = 10,
            stamina = 15
        },
        base_health = 40,
        health_growth = 1.12,     -- +12% здоровья за уровень
        damage_growth = 1.06, -- +6% урона за уровень
        base_speed = 90,      -- скелеты ходят чуть медленнее игрока
        hitbox_size = 64,
        animation = "skeleton_warrior",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol",
        base_aggro_radius = 450,
        faction = "undead",
        default_rank = "common",
        abilities = { "melee_attack" }
    },
    ["dire_boar"] = {
        name_key = "unit_dire_boar_name",
        type = "beast",
        unit_class = {
            warrior = true
        },
        base_stats = {
            strength = 17,
            agility = 10,
            intellect = 4,
            stamina = 12
        },
        base_health = 50,         -- ХП на 1 уровне
        health_growth = 1.15,     -- +15% ХП за каждый уровень
        damage_growth = 1.08, -- +8% урона за уровень
        base_speed = 120,     -- базовая скорость бега
        hitbox_size = 64,
        animation = "boar_idle",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol",
        base_aggro_radius = 350,
        faction = "beast_neutral",
        default_rank = "common",
        abilities = { "melee_attack" }
    },
    ["elder_green_dragon"] = {
        name_key = "unit_elder_green_dragon_name",
        race = "dragon",
        type = "dragon",
        unit_class = {
            warrior = true,
            mage = true,
            priest = true
        },
        base_stats = {
            strength = 42,
            agility = 27,
            intellect = 39,
            stamina = 72
        },
        base_health = 420,
        health_growth = 1.12,     -- +12% здоровья за уровень
        damage_growth = 1.2, -- +6% урона за уровень
        base_speed = 175,      -- скелеты ходят чуть медленнее игрока
        hitbox_size = 128,
        spellcast_range = 120,
        animation = "elder_green_dragon",
        texture = "project_utumno",
        ai_profile = "aggressive_patrol",
        base_aggro_radius = 550,
        faction = "green_dragon",
        default_rank = "elite",
        abilities = { "melee_attack" }
    },

}

-- Быстрый кэш хэшированных ключей для мгновенного поиска из go.property
---@type any
local units_by_hash = {}

for id_str, data in pairs(M.units) do
    data.id = id_str
    units_by_hash[hash(id_str)] = data
end

---Универсальная быстрая функция получения статического конфига существа
---@param id any Идентификатор существа (хэш Defold или чистая Lua-строка)
---@return UnitConfig|nil data Ссылка на статический конфиг или nil
function M.get_unit(id)
    -- Если прилетел хэш (из go.property в unit.script), мгновенно забираем из кэша. 
    -- Если прилетела строка (из сумок или логов), забираем из M.units.
    return units_by_hash[id] or M.units[id]
end

return M
