local broadcast = require("main.modules.system.broadcast")
local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")

local M = {}

-- 🎯 ГИГИЕНА: Единый пуленепробиваемый путь к JSON файлу сохранения
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.json")

-- Рекурсивная проверка и конвертация типов Defold в типы JSON
local function prepare_for_json(t)
    if type(t) ~= "table" then
        -- Если это хэш движка, переводим в строку (или число), но лучше вообще не допускать
        if type(t) == "userdata" then 
            return tostring(t) -- Хэш превратится в "[hash: 'id']" или хекс-строку. Сейв не упадет.
        end
        return t
    end

    -- Проверяем, не vector3 ли это от Defold
    if t.x and t.y and type(t) ~= "table" then 
        return { x = t.x, y = t.y, z = t.z or 0 }
    end

    local clean = {}
    for k, v in pairs(t) do
        -- Ключи JSON могут быть ТОЛЬКО строками. Хэш в качестве ключа — смерть для json.encode
        local clean_key = type(k) == "userdata" and tostring(k) or k
        clean[clean_key] = prepare_for_json(v)
    end
    return clean
end


---@return boolean Проверить существует ли файл сохранения на диске ПК (Для кнопки Continue)
function M.exists()
    local file = io.open(SAVE_PATH, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

---Инициализировать стейт Памяти под Новую Игру (Канон WoW)
function M.new_game()
    -- 1. Стерильно очищаем все домены данных в оперативной памяти Lua
    game_state.clear_all()
    player_inventory.clear()
    player_paperdoll.clear()

    -- Насыпаем стартовый ААА-эквип магу в рюкзак
    player_inventory.init()
    player_inventory.add_item("iron_sword", 1)
    player_inventory.add_item("lesser_mana_potion", 10)
    player_inventory.add_item("leather_helmet", 1)
    player_inventory.add_item("clown_hat", 1)
    player_inventory.add_item("crystal_sword", 1)

    -- Настраиваем дефолтную раскладку экшен-баров на HUD
    character_data.player.action_bars = {
        [1] = {
            [1] = { action_type = "ability", action_id = "melee_attack" },
            [2] = { action_type = "ability", action_id = "frostbolt" },
            [3] = { action_type = "item",    action_id = "lesser_mana_potion" },
            [4] = { action_type = "item",    action_id = "iron_sword" },
        },
        [2] = {},
    }

    -- Перезапускаем Proxy-коллекцию мира. Все маркеры редактора запекутся с нуля!
    msg.post("main:/loader#script", "reload_game", { last_pos = nil })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed")})
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    broadcast.send("log_events", { message_id = hash("log_clear") })
end

---Засейвить игру на жесткий диск ПК (JSON-монолит)
---@return boolean
function M.save_game()
    -- Безопасно распаковываем позицию игрока, гарантируя, что vector3 не уйдет в JSON
    local p_pos = character_data.player.last_pos
    local serializable_pos = { x = p_pos.x, y = p_pos.y, z = p_pos.z or 0 }

    local data = {
        version = 1,
        time = os.time(),
        inventory = player_inventory.get_save_data(),
        paperdoll = player_paperdoll.get_save_data(),
        player = {
            level = character_data.player.level,
            experience = character_data.player.experience,
            health = character_data.player.health,
            last_pos = serializable_pos, -- Сюда ушла чистая таблица
            action_bars = prepare_for_json(character_data.player.action_bars) -- Чистим экшн-бары от хэшей
        },
        world = game_state.get_full_save_data() -- Модуль предметов с земли (там все чисто, только строки)
    }

    local file = io.open(SAVE_PATH, "w+")
    if file then
        -- На всякий случай прогоняем весь монолит через фильтр типов
        local success, json_string = pcall(json.encode, prepare_for_json(data))
        if not success then
            print("🚨 БЭКЕНД: Критическая ошибка сериализации! В данных остался userdata/hash!")
            file:close()
            return false
        end

        file:write(json_string)
        file:close()
        print("💾 БЭКЕНД [SaveManager]: Сейв успешно записан на диск ПК (JSON-монолит)")
        return true
    end

    print("🚨 БЭКЕНД [SaveManager]: ОШИБКА! Не удалось открыть файл для записи!")
    return false
end

---Загрузить игру из файла сохранения JSON
---@return boolean
function M.load_game()
    local file = io.open(SAVE_PATH, "r")
    if not file then return false end

    local content = file:read("*all")
    file:close()

    local data = json.decode(content)
    if not data then return false end

    player_inventory.load_save_data(data.inventory)
    player_paperdoll.load_save_data(data.paperdoll)
    character_data.player.action_bars = data.player.action_bars
    
    game_state.restore_all(data.world)

    -- 🎯 КРИТИЧЕСКИЙ ФИКС: Конвертируем таблицу координат обратно в вектор Defold
    local saved_pos = data.player.last_pos
    local live_vector_pos = vmath.vector3(saved_pos.x, saved_pos.y, saved_pos.z or 0)
    
    -- Обновляем живое состояние в RAM игры
    character_data.player.last_pos = live_vector_pos

    -- Передаем в прокси-лоадер валидный vector3
    msg.post("main:/loader#script", "reload_game", {
        is_load = true,
        last_pos = live_vector_pos,
        action_bars = data.player.action_bars
    })
    
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    print("💾 БЭКЕНД [SaveManager]: Сейв успешно развернут. Векторы восстановлены!")
    return true
end

return M
