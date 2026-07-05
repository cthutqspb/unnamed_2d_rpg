---@class UnitIdentity
---@field name_key string Локализационный ключ имени существа
---@field race string|nil Человек, огр, гоблин, дварф, эльф
---@field faction string
---@field type string  Нежить, дракон, животное, конструкция, потустороннее, демон, бог
---@field default_rank string
---@field unit_class table <string, boolean> Маг, жрец, воин, разбойник
---@field loot_table_id string|nil    

---@class UnitAttributes
---@field agility number
---@field intellect number
---@field stamina number
---@field strength number

---@class UnitParameters
---@field base_health number Базовое здоровье на 1 уровне
---@field base_speed number Базовая скорость перемещения в пикселях
---@field hitbox_size number

---@class UnitProgression
---@field health_growth number Коэффициент роста ХП за каждый уровень (например, +15% это 1.15)
---@field damage_growth number Коэффициент роста урона за уровень

---@class UnitResource
---@field type "mana"|"rage"|"energy"|string Строковый тип энергии (индекс ресурса)
---@field current number
---@field max number

---@class UnitVisuals
---@field animation string Имя дефолтной анимации покоя в атласе
---@field texture string Имя графического атласа/тайлсорса

---@class UnitAI
---@field profile string
---@field base_aggro_radius number
---@field is_ranged boolean
---@field flee_range number
---@field tag_weights table

---@class UnitConfig
---@field identity UnitIdentity       🆔 Метаданные и паспорт личности
---@field attributes UnitAttributes   🧬 Core-атрибуты (Сила, Ловкость, Интеллект, Стамина)
---@field parameters UnitParameters   📊 Вторичные боевые параметры (base_health, base_speed, hitbox_size)
---@field progression UnitProgression 📈 Коэффициенты скалирования за уровень
---@field resource UnitResource       🧪 Дефолтный шаблон ресурсов маны/ярости
---@field visuals UnitVisuals         🎨 Графика, скины и анимации отрисовки
---@field ai UnitAI                   🧠 Профиль ИИ, веса личности и кайтинг
---@field abilities string[]          ⚔️ Плоский массив ротации спеллов существа
---@field id string|nil

local M = {}

---@type table<string, UnitConfig>
M.units = {
     ["skeleton_warrior"] = {
        identity = {
            name_key = "unit_skeleton_warrior_name",
            race = "elf",
            faction = "undead",
            type = "skeleton",
            default_rank = "common",
            unit_class = {
                warrior = true
            },
        },
        attributes = {
            strength = 14,
            agility = 12,
            intellect = 10,
            stamina = 15
        },
        parameters = {
            base_health = 40,
            base_speed = 90,      -- скелеты ходят чуть медленнее игрока
            hitbox_size = 64,
        },
        progression = {
            health_growth = 1.12,     -- +12% здоровья за уровень
            damage_growth = 1.06, -- +6% урона за уровень
        },
        resource = {
            type = "rage",
            current = 0,
            max = 100
        },
        visuals = {
            animation = "skeleton_warrior",
            texture = "project_utumno",
        },
        ai = {
            profile = "aggressive_patrol",
            base_aggro_radius = 450,
            is_ranged = false,
            flee_range = 0,
            tag_weights = {
                ["damage"] = 1.5,
                ["control"] = 0.5,
                ["melee_attack"] = 2.0,
                ["ranged_attack"] = 0.0
            }
        },
        abilities = { "melee_attack" }
    },
    ["skeleton_mage"] = {
        identity = {
            name_key = "unit_skeleton_mage_name",
            race = "human",
            faction = "undead",
            type = "skeleton",
            default_rank = "common",
            unit_class = {
                mage = true
            },
        },
        attributes = {
            strength  = 8,
            agility   = 8,
            intellect = 23,
            stamina   = 15
        },
        parameters = {
            base_health = 40,
            base_speed  = 90,
            hitbox_size = 64,
        },
        progression = {
            health_growth = 1.12,
            damage_growth = 1.06,
        },
        resource = {
            type    = "mana",
            current = 100,
            max     = 100
        },
        visuals = {
            animation = "skeleton_mage",
            texture = "project_utumno",
        },
        ai = {
            profile = "aggressive_patrol",
            base_aggro_radius = 450,
            is_ranged = true,
            flee_range = 140,
            tag_weights = {
                ["damage"] = 1.5,
                ["control"] = 1.0,
                ["melee_attack"] = 0.5,
                ["ranged_attack"] = 1.0
            },
        },
        abilities = {
            "melee_attack",
            "lightning_bolt"
        }
    },
    ["dire_boar"] = {
        identity = {
            name_key = "unit_dire_boar_name",
            faction = "beast_neutral",
            type = "beast",
            default_rank = "common",
            unit_class = {
                warrior = true
            },
        },
        attributes = {
            strength = 17,
            agility = 10,
            intellect = 4,
            stamina = 12
        },
        parameters = {
            base_health = 50,
            base_speed  = 120,
            hitbox_size = 64,
        },
        progression = {
            health_growth = 1.15,
            damage_growth = 1.08,
        },
        resource = {
            type    = "rage",
            current = 100,
            max     = 100
        },
        visuals = {
            animation = "boar_idle",
            texture = "project_utumno",
        },
        ai = {
            profile = "aggressive_patrol",
            base_aggro_radius = 450,
            is_ranged = false,
            flee_range = 0,
            tag_weights = {
                ["damage"] = 1.5,
                ["control"] = 0.5,
                ["melee_attack"] = 0.5,
                ["ranged_attack"] = 0.0
            },
        },
        abilities = {
            "melee_attack",
        }
    },
    ["elder_green_dragon"] = {
        identity = {
            name_key = "unit_elder_green_dragon_name",
            race = "dragon",
            faction = "dragon",
            type = "dragon",
            default_rank = "rare",
            unit_class = {
                warrior = true,
                mage = true,
                priest = true
            },
        },
        attributes = {
            strength = 42,
            agility = 27,
            intellect = 39,
            stamina = 72
        },
        parameters = {
            base_health = 140,
            base_speed  = 175,
            hitbox_size = 128,
        },
        progression = {
            health_growth = 1.17,
            damage_growth = 1.2,
        },
        resource = {
            type    = "mana",
            current = 170,
            max     = 170
        },
        visuals = {
            animation = "elder_green_dragon",
            texture = "project_utumno",
        },
        ai = {
            profile = "aggressive_patrol",
            base_aggro_radius = 550,
            is_ranged = true,
            flee_range = 0,
            tag_weights = {
                ["damage"] = 1.5,
                ["control"] = 1.0,
                ["melee_attack"] = 0.5,
                ["ranged_attack"] = 1.0
            },
        },
        abilities = {
            "melee_attack",
            "lightning_bolt"
        }
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
