---@class LocaleManagerModule
local M = {}

-- 🎯 ТИПИЗАЦИЯ СЛОВАРЕЙ: Кастуем таблицы как any, чтобы линтер полностью выключил 
-- проверки inject-field на динамическую склейку словарей и чтение хэш-ключей!
---@type any
M.data = {}

---@type any
local hash_to_string_map = {} -- Наша карта хешей

local current_lang = "ru"

local LOCALES = {
    ru = {
        ui = require("main.modules.data.locales.ru.ui"),
        items = require("main.modules.data.locales.ru.items"),
        units = require("main.modules.data.locales.ru.units"),
        abilities = require("main.modules.data.locales.ru.abilities")
    },
    en = {
        ui = require("main.modules.data.locales.en.ui"),
        items = require("main.modules.data.locales.en.items"),
        units = require("main.modules.data.locales.en.units"),
        abilities = require("main.modules.data.locales.en.abilities")
    }
}

---Вспомогательная функция глубокого слияния словарей локализации
---@local
---@param target any Целевая таблица сбора локалей
---@param source table|nil Исходный файл словаря конкретной категории локали
local function merge_tables(target, source)
    if not source then return end
    for k, v in pairs(source) do
        target[k] = v
    end
end

---Внутренняя функция пересборки карты хешей (вызывается на ходу при смене языка)
---@local
local function rebuild_hash_map()
    hash_to_string_map = {}
    for key, value in pairs(M.data) do
        hash_to_string_map[hash(key)] = value
    end
end

---Принудительно загрузить язык локализации, пересобрать таблицы и кэш хэшей
---@param lang string Код языка ("ru", "en")
function M.load_language(lang)
    local locale = LOCALES[lang]
    if not locale then return end

    M.data = {}
    merge_tables(M.data, locale.ui)
    merge_tables(M.data, locale.items)
    merge_tables(M.data, locale.units)
    merge_tables(M.data, locale.abilities)

    current_lang = lang
    rebuild_hash_map() -- ОБЯЗАТЕЛЬНО обновляем карту после загрузки данных
end

-- Стартовая инициализация дефолтного языка при загрузке модуля
M.load_language(current_lang)

---Получить переведённую строку по её ключу
---@param key hash|string|nil Ключ локализации (хэш Defold или чистая Lua-строка)
---@return string translated_text Итоговый переведенный текст или дебаг-заглушка с именем ключа
function M.get(key)
    if not key then return "" end

    -- 1. Если пришел ХЕШ (userdata из go.property)
    if type(key) == "userdata" then
        return hash_to_string_map[key] or ("#[" .. tostring(key) .. "]")
    end

    -- 2. Если пришла СТРОКА
    return M.data[key] or ("[" .. tostring(key) .. "]")
end

return M

