local broadcast = require("main.modules.system.broadcast")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")

---@class SaveManagerModule
local M = {}

-- 🎯 ГИГИЕНА: Единый пуленепробиваемый путь к JSON файлу сохранения
---@type string
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.json")

-- =========================================================================
-- 🛡️ ААА-АТРИБУТ [JsonIgnore]: ТИТАНОВЫЙ ЧЕРНЫЙ СПИСОК РЕКУРСИЙ
-- =========================================================================
-- Сюда мы заносим любые служебные поля, ссылки на Си-объекты или обратные указатели,
-- которые JSON-устройство обязано НАГЛУХО игнорировать при записи игры на жесткий диск ПК.
local JSON_IGNORE_FIELDS = {
    ["owner"] = true,  -- Наша главная обратная ссылка «Рюкзак/Кукла -> Хозяин-Юнит»
    -- ["current_target"] = true, -- Сюда в будущем можно вписать ИИ-таргет монстра!
}

-- Рекурсивная проверка и конвертация типов Defold в типы JSON (Твой оригинальный код!)
---@param t any Входящие данные любого типа
---@return any Очищенная от хэшей таблица или примитив
local function prepare_for_json(t)
    -- 🎯 1. ТВОЙ ПУЛЕНЕПРОБИВАЕМЫЙ ПЕРЕХВАТ ВЕКТОРОВ DEFOLD (WoW/BG3 канон):
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

    -- 3. РЕКУРСИВНЫЙ ОБХОД ТАБЛИЦ (Твой оригинальный рабочий код!)
    local clean = {}
    for k, v in pairs(t) do
        -- 🦾 УЛЬТИМАТИВНЫЙ AAA-ПЕРЕХВАТЧИК [JsonIgnore] (ИСПРАВЛЕНО И ЗАФИКСИРОВАНО):
        -- Мы проверяем, лежит ли текущий ключ в нашем черном списке рекурсий.
        -- Если чистильщик видит поле "owner" — он СЛЕПО ПРОПУСКАЕТ эту итерацию!
        -- Мертвая петля рекурсии "маг -> рюкзак -> маг" разрывается посреди кадра на корню!
        local clean_key = type(k) == "userdata" and tostring(k) or k
        if not JSON_IGNORE_FIELDS[k] then
            -- Ключи JSON могут быть ТОЛЬКО строками. Хэш-ключ — смерть для json.encode
              clean[clean_key] = prepare_for_json(v)
        end
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
    --player_paperdoll.clear()

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
    local player_data = game_state.get_player_data()

    if player_data and player_data.inventory then
        -- Очищаем рюкзак мага перед выдачей стартового сета
        player_data.inventory:clear()

        -- 🎯 НАВАЛИВАЕМ СТАРТОВЫЙ ЛУТ СТРОГО В ОБЪЕКТНЫЙ ИНСТАНС ИЗ ПАСПОРТА!
        -- Метод :add_item сам сочно раскидает мечи и банки по ячейкам в памяти RAM,
        -- а GUI-окно при открытии мгновенно и безбажно отрендерит эти иконки на экране!
        player_data.inventory:add_item("iron_sword", 1)
        player_data.inventory:add_item("lesser_mana_potion", 10)
        player_data.inventory:add_item("leather_helmet", 1)
        player_data.inventory:add_item("clown_hat", 1)
        player_data.inventory:add_item("crystal_sword", 1)

        print("💾 БЭКЕНД: Стартовый лут Новой Игры успешно засыпан в RAM-паспорт мага!")
    else
        print("🚨 БЭКЕНД: Не удалось выдать стартовый шмот, инвентарь игрока не инициализирован!")
    end

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
    local player_unit = game_state.get_player_data()
    if not player_unit then return false end

    local player_position = player_unit.saved_position
    local serializable_position = { x = player_position.x, y = player_position.y, z = player_position.z or 0 }

    -- Твой чистый, плоский сбор монолита под сохранение
    local data = {
        version = 1,
        time = os.time(),
        player = {
            level = player_unit.level,
            experience = player_unit.experience,
            health = player_unit.health,
            saved_position = serializable_position,
            action_bars = player_unit.action_bars, -- чистильщик сам сожрет хэши экшен-баров

            -- Вызываем у рюкзака и куклы мага их плоские методы сохранения ячеек!
            inventory = player_unit.inventory and player_unit.inventory:get_save_data() or {},
            paperdoll = player_unit.paperdoll and player_unit.paperdoll:get_save_data() or {}
        },
        -- Твой красивый старый метод сбора вселенной Meadows из game_state.lua!
        world = game_state.get_full_save_data()
    }

    local file = io.open(SAVE_PATH, "w+")
    if file then
        -- 🚀 ЧИСТО КРАСИВЫЙ AAA-ПРОГОН: 
        -- Наш prepare_for_json сожрёт всю эту гигантскую матрешку мира со всеми 
        -- скелетами и вещами за один Си-такт, наглухо проигнорировав 'owner'!
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

    game_state.restore_all(data.world)

    local player_unit = game_state.get_player_data()

    if player_unit then
        -- 🦾 НАКАТЫВАЕМ ОБЪЕКТНЫЕ ДАННЫЕ ВНУТРЬ ИНСТАНСОВ ЮНИТА (ИСПРАВЛЕНО):
        -- Мы вызываем объектные методы :load_save_data через двоеточие строго на тех 
        -- компонентах, которые нативно принадлежат нашему новому магу!
        if data.player.inventory and player_unit.inventory then
            player_unit.inventory:load_save_data(data.player.inventory)
        end
        if data.player.paperdoll and player_unit.paperdoll then
            player_unit.paperdoll:load_save_data(data.player.paperdoll)
        end

        player_unit.action_bars = data.player.action_bars
        player_unit.experience = data.player.experience or 0
        player_unit.level = data.player.level or 1
        player_unit.health = data.player.health or 100
    end

    character_data.bind_to_units_registry()

    -- Читаем координаты напрямую из юнита игрока через ссылку-мост
    local saved_position = character_data.player.saved_position

    -- Конвертируем обратно в Си-вектор для прокси-лоадера Defold
    local base_x = saved_position and saved_position.x or 0
    local base_y = saved_position and saved_position.y or 0
    local base_z = saved_position and saved_position.z or 1.0

    -- Конвертируем обратно в Си-вектор для прокси-лоадера Defold
    local live_vector_position = vmath.vector3(base_x, base_y, base_z)

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
