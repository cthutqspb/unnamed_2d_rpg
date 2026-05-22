local locales = require("main.modules.data.locales.locale_manager")
local SaveManager = require("main.modules.system.SaveManager")

local M = {}

function M.new(druid, template_id)
    local self = {
        druid = druid,
        root = gui.get_node("root"),
        btn_new_game = druid:new_button("btn_new_game", function() M.on_new_game(self) end),
        btn_continue_game = druid:new_button("btn_continue_game", function() M.on_continue(self) end),
        btn_exit_game = druid:new_button("btn_exit_game", function() sys.exit(0) end),
        btn_new_game_title = gui.get_node("btn_new_game_title"),
        btn_continue_game_title = gui.get_node("btn_continue_game_title"),
        btn_save_game_title = gui.get_node("btn_save_game_title"),
        btn_load_game_title = gui.get_node("btn_load_game_title"),
        btn_exit_game_title = gui.get_node("btn_exit_game_title"),
    }

    self.is_visible = M.is_visible
    self.set_visible = M.set_visible
    self.toggle = M.toggle
    self.on_new_game = M.on_new_game
    self.on_continue = M.on_continue
    self.on_save_game = M.on_save_game
    self.on_load_game = M.on_load_game

    -- Можно сразу добавить визуальные эффекты при наведении
    self.btn_new_game:set_click_zone(gui.get_node("btn_new_game"))

    self.btn_new_game = druid:new_button("btn_new_game", function() self:on_new_game() end)
    self.btn_continue_game = druid:new_button("btn_continue_game", function() self:on_continue() end)
    self.btn_save_game = druid:new_button("btn_save_game", function() self:on_save_game() end)
    self.btn_load_game = druid:new_button("btn_load_game", function() self:on_load_game() end)

    gui.set_text(self.btn_new_game_title, tostring(locales.get("btn_new_game")))
    gui.set_text(self.btn_continue_game_title, tostring(locales.get("btn_continue_game")))
    gui.set_text(self.btn_save_game_title, tostring(locales.get("btn_save_game")))
    gui.set_text(self.btn_load_game_title, tostring(locales.get("btn_load_game")))
    gui.set_text(self.btn_exit_game_title, tostring(locales.get("btn_exit_game")))

    return self
end

function M:is_visible()
    return gui.is_enabled(self.root)
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    -- Если меню активно, оно должно "съедать" весь ввод
    if visible then
        msg.post(".", "acquire_input_focus")
    else
        msg.post(".", "release_input_focus")
    end
end

function M:toggle()
    self:set_visible(not self:is_visible())
end

function M:on_new_game()
    print("Starting New Game...")
    -- Здесь будет логика сброса всех модулей (инвентарь, статы) в nil
    SaveManager.new_game();
    self:set_visible(false)
    msg.post("world", "start_game") -- Сигнал миру "погнали"
end

function M:on_continue()
    if SaveManager.load_game() then
        self:set_visible(false)
        print("Game Loaded Successfully")
    end
end

function M:on_save_game()
    print("Saving game...")
    SaveManager.save_game();
    self:set_visible(false)
    msg.post("world", "save_game")
end

function M:on_load_game()
    print("Loading saving game...")
    SaveManager.load_game();
    self:set_visible(false)
    msg.post("world", "load_game")
end

return M

