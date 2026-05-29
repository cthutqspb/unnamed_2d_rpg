---@class RaceConfig
---@field name_key string Локализационный ключ названия расы
---@field base_stats table<string, integer> Базовые характеристики расы (сила, ловкость и т.д.)

---@class ClassConfig
---@field name_key string Локализационный ключ названия класса

---@class StatConfig
---@field name_key string Локализационный ключ названия характеристики
---@field base integer Дефолтное базовое значение характеристики для расчётов

---@class CharacterConfigModule
---@field races table<string, RaceConfig> Словарь доступных рас персонажа
---@field classes table<string, ClassConfig> Словарь доступных игровых классов
---@field stats table<string, StatConfig> Словарь базовых характеристик
local M = {}

M.races = {
    human = {
        name_key = "race_human",
        base_stats = {
            strength = 10,
            agility = 10,
            intellect = 10,
            stamina = 10
        }
    },
    elf = {
        name_key = "race_elf",
        base_stats = {
            strength = 8,
            agility = 12,
            intellect = 12,
            stamina = 8
        }
    },
    dwarf = {
        name_key = "race_dwarf",
        base_stats = {
            strength = 12,
            agility = 8,
            intellect = 8,
            stamina = 12
        }
    }
}

M.classes = {
    warrior = { name_key = "class_warrior" },
    mage = { name_key = "class_mage" },
    rogue = { name_key = "class_rogue" }
}

M.stats = {
    strength = { name_key = "stat_strength", base = 10 },
    agility = { name_key = "stat_agility", base = 10 },
    intellect = { name_key = "stat_intellect", base = 10 },
    stamina = { name_key = "stat_stamina", base = 10 }
}

return M
