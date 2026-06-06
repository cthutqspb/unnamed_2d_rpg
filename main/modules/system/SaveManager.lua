local settings = require("main.modules.data.settings")
local broadcast = require("main.modules.system.broadcast")
local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")
local character_logic = require("main.modules.character.character_logic")

local M = {}

local SAVE_FILE = "save_01.dat"
-- Вместо get_save_config
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.dat")

-- ПРОВЕРКА: есть ли сейв вообще? (Для кнопки Continue)
function M.exists()
    local file = io.open(SAVE_PATH, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

function M.new_game()
    -- 1. Стираем данные в Lua-модулях
    game_state.clear_all()
    player_inventory.clear()
    player_paperdoll.clear()

    player_inventory.init() -- заполняем ячейки пустышками
    player_inventory.add_item("iron_sword", 1)
    player_inventory.add_item("lesser_mana_potion", 10)
    player_inventory.add_item("leather_helmet", 1)
    player_inventory.add_item("clown_hat", 1)
    player_inventory.add_item("crystal_sword", 1)

    -- 2. ДИНАМИЧЕСКИЙ ДЕФОЛТ ДЛЯ МAГA В СТEЙТ ПAМЯТИ:
    -- Наполняем пустую таблицу character_data.player.action_bars нужной раскладкой.
    -- В Луа массивы идут строго с 1, поэтому прописываем индексы явно [1] и [2]!
    character_data.player.action_bars = {
        [1] = { -- Основная панель (кнопки 1, 2, 3... 12)
            [1] = { action_type = "ability", action_id = "melee_attack" },
            [2] = { action_type = "ability", action_id = "frostbolt" },
            [3] = { action_type = "item",    action_id = "lesser_mana_potion" }, -- Юзабельное зелье [C]
            [4] = { action_type = "item",    action_id = "iron_sword" },
            -- остальные слоты в Lua автоматически останутся nil
        },
        [2] = {}, -- Нижняя левая панель (пока пустая, ждет кнопок через Shift)
    }

    -- 2. ГОВОРИМ ЛОАДЕРУ: Перезагрузи всю сцену
    msg.post("main:/loader#script", "reload_game", { last_pos = nil })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed")})
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    -- Всё! При старте новой сцены все init() сработают на чистых данных
end

-- СОХРАНЕНИЕ
function M.save_game()
    local data = {
        version = 1,
        time = os.time(),
        inventory = player_inventory.get_save_data(),
        paperdoll = player_paperdoll.get_save_data(),
        player = {
            level = character_data.player.level,
            experience = character_data.player.experience,
            health = character_data.player.health,
            last_pos = character_data.player.last_pos,
            action_bars = character_data.player.action_bars
        },
        world = game_state.get_full_save_data()
    }

    local path = sys.get_save_file("MyAwesomeRPG", "save_01.json")
    local file = io.open(path, "w+")
    if file then
        file:write(json.encode(data))
        file:close()
        print("SUCCESS: Game Saved (JSON)")
        return true
    end
    print("ERROR: Save Failed")
    return false
end

function M.load_game()
    local path = sys.get_save_file("MyAwesomeRPG", "save_01.json")
    local file = io.open(path, "r")
    if not file then return false end

    local content = file:read("*all")
    file:close()

    local data = json.decode(content)
    if not data then return false end

    -- Дальше твоя обычная логика восстановления
    player_inventory.load_save_data(data.inventory)
    player_paperdoll.load_save_data(data.paperdoll)
    character_data.player.action_bars = data.player.action_bars
    game_state.restore_all(data.world)

    -- character_data.player.last_pos = data.player.last_pos
    -- ...

    msg.post("main:/loader#script", "reload_game", {
        is_load = true,
        last_pos = data.player.last_pos,
        action_bars = data.player.action_bars
    })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    return true
end

return M
