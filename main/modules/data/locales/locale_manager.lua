local M = {}

M.data = {}
local hash_to_string_map = {} -- Наша карта хешей
local current_lang = "ru"

local LOCALES = {
    ru = {
        ui = require("main.modules.data.locales.ru.ui"),
        items = require("main.modules.data.locales.ru.items")
    },
    en = {
        ui = require("main.modules.data.locales.en.ui"),
        items = require("main.modules.data.locales.en.items")
    }
}

local function merge_tables(target, source)
    if not source then return end
    for k, v in pairs(source) do
        target[k] = v
    end
end

-- Функция пересборки карты хешей
local function rebuild_hash_map()
    hash_to_string_map = {}
    for key, value in pairs(M.data) do
        hash_to_string_map[hash(key)] = value
    end
end

function M.load_language(lang)
    local lang_data = LOCALES[lang]
    if not lang_data then return end

    M.data = {}
    merge_tables(M.data, lang_data.ui)
    merge_tables(M.data, lang_data.items)
    
    current_lang = lang
    rebuild_hash_map() -- ОБЯЗАТЕЛЬНО обновляем карту после загрузки данных
end

M.load_language(current_lang)

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

