local broadcast = require("main.modules.system.broadcast")
local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")

---@class SaveManagerModule
local M = {}

-- 🎯 ГИГИЕНА: Единый пуленепробиваемый путь к JSON файлу сохранения
---@type string
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.json")

-- Рекурсивная проверка и конвертация типов Defold в типы JSON
---@param t any Входящие данные любого типа
---@return any Очищенная от хэшей таблица или примитив
local function prepare_for_json(t)
    -- 🎯 1. ПУЛЕНЕПРОБИВАЕМЫЙ ПЕРЕХВАТ ВЕКТОРОВ DEFOLD (WoW/BG3 канон):
    -- Если прилетел userdata-вектор, у него тип равен "userdata", но у него ЕСТЬ поля x и y!
    -- Мы проверяем это первой строчкой через pcall (чтобы не крашнулось на голых хэшах).
    -- Если это вектор — мгновенно раскладываем его в стерильную JSON-таблицу чисел {x, y, z}!
    if type(t) == "userdata" and pcall(function() return t.x and t.y end) then
        return { x = t.x, y = t.y, z = t.z or 0 }
    end

    -- 2. ГВАРД ДЛЯ ОСТАЛЬНЫХ СИ-ТИПОВ (Голые Хэши движка):
    -- Сюда зайдут только чистые Си-хэши hash("skeleton_warrior"), у которых нет полей x и y.
    -- Они канонично превратятся в безопасный текст, чтобы json.encode не рушил игру.
    if type(t) ~= "table" then
        if type(t) == "userdata" then
            return tostring(t)
        end
        return t
    end

    -- 3. РЕКУРСИВНЫЙ ОБХОД ТАБЛИЦ (Твой оригинальный рабочий код)
    local clean = {}
    for k, v in pairs(t) do
        -- Ключи JSON могут быть ТОЛЬКО строками. Хэш-ключ — смерть для json.encode
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
function M.new_game(creation_package)
    -- 1. Стерильно очищаем все домены данных в оперативной памяти Lua
    game_state.clear_all()
    player_inventory.clear()
    player_paperdoll.clear()

     -- 🛡️ ВЫТАCКИВАЕМ ДЕФОЛТЫ ИЗ АРХЕТИПА:
    -- Если пакет не прилетел (тест из редактора), ставим жесткий фоллбек,
    -- но если пакет есть — игра запустится с тем именем и классом, что выбрал игрок!
    local character = creation_package or {
        unit_id = "player_mage",
        name_key = "class_mage",
        stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
    }

    -- Рожаем Юнита игрока в RAM на основе прилетевшего пакета!
    game_state.create_player_unit({
        unit_id = character.unit_id,
        name_key = character.name_key,
        is_player = true,
        level = 1,
        experience = 0,
        health = 100,
        max_health = 100,
        mana = 50,
        max_mana = 50,
        stats = character.stats,
        current_stats = character.stats,
        saved_position = vmath.vector3(1126, 725, 1.0)
    })

    -- Намертво привязываем мост
    character_data.bind_to_units_registry()

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
    msg.post("main:/loader#script", "reload_game", { saved_position = nil })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed")})
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    broadcast.send("log_events", { message_id = hash("log_clear") })
end

---Засейвить игру на жесткий диск ПК (JSON-монолит)
---@return boolean
function M.save_game()
    -- Безопасно распаковываем позицию игрока, гарантируя, что vector3 не уйдет в JSON
    local player_position = character_data.player.saved_position
    local serializable_position = { x = player_position.x, y = player_position.y, z = player_position.z or 0 }

    local data = {
        version = 1,
        time = os.time(),
        inventory = player_inventory.get_save_data(),
        paperdoll = player_paperdoll.get_save_data(),
        player = {
            level = character_data.player.level,
            experience = character_data.player.experience,
            health = character_data.player.health,
            saved_position = serializable_position, -- Сюда ушла чистая таблица
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
    -- character_data.player.action_bars = data.player.action_bars

    game_state.restore_all(data.world)

    local player_unit = game_state.get_player_data()

    if player_unit then
        player_unit.action_bars = data.player.action_bars
        player_unit.experience = data.player.experience or 0
        player_unit.level = data.player.level or 1
        -- (и любые другие статы игрока из секции data.player, если они там разделены)
    end
    character_data.bind_to_units_registry()
    
    -- Читаем координаты напрямую из юнита игрока через ссылку-мост
    local saved_position = character_data.player.saved_position
    
    -- Конвертируем обратно в Си-вектор для прокси-лоадера Defold
    local live_vector_position = vmath.vector3(saved_position.x, saved_position.y, saved_position.z or 1.0)
    character_data.player.saved_position = live_vector_position

    -- Передаем в лоадер
    msg.post("main:/loader#script", "reload_game", {
        is_load = true,
        saved_position = live_vector_position,
        action_bars = data.player.action_bars
    })

    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    broadcast.send("ui_events", { message_id = hash("clear_world_ui") })

    print("💾 БЭКЕНД [SaveManager]: Сейв успешно развернут. Векторы восстановлены!")
    return true
end

return M
