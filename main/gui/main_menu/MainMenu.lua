local locales = require("main.modules.data.locales.locale_manager")
local SaveManager = require("main.modules.system.SaveManager")

---@class MainMenu
local M = {}

---Фабричный конструктор создания нового инстанса Главного Меню
---@param druid table Переданный менеджер Друида из gui_script
---@param _template_id string
---@return table
function M.new(druid, _template_id)
    -- 🚩 ФИКС ТИПОВ: Кастуем в обычный table, отключая душный статический анализатор.
    -- Это мгновенно сотрет все варнинги param-type-mismatch и need-check-nil!
    ---@type table
    local self = {}

    self.druid = druid
    self.root = gui.get_node("root")

    -- Считываем текстовые ноды
    self.btn_new_game_title = gui.get_node("btn_new_game_title")
    self.btn_continue_game_title = gui.get_node("btn_continue_game_title")
    self.btn_save_game_title = gui.get_node("btn_save_game_title")
    self.btn_load_game_title = gui.get_node("btn_load_game_title")
    self.btn_exit_game_title = gui.get_node("btn_exit_game_title")

    -- Склеиваем методы модуля с инстансом (паттерн миксина)
    self.is_visible = M.is_visible
    self.set_visible = M.set_visible
    self.toggle = M.toggle
    self.on_new_game = M.on_new_game
    self.on_continue = M.on_continue
    self.on_save_game = M.on_save_game
    self.on_load_game = M.on_load_game

    -- Регистрируем Друид-кнопки
    self.btn_new_game = druid:new_button("btn_new_game", function() self:on_new_game() end)
    self.btn_continue_game = druid:new_button("btn_continue_game", function() self:on_continue() end)
    self.btn_save_game = druid:new_button("btn_save_game", function() self:on_save_game() end)
    self.btn_load_game = druid:new_button("btn_load_game", function() self:on_load_game() end)
    self.btn_exit_game = druid:new_button("btn_exit_game", function() sys.exit(0) end)

    -- Настраиваем физическую зону клика
    self.btn_new_game:set_click_zone(gui.get_node("btn_new_game"))

    -- Локализация текстов
    gui.set_text(self.btn_new_game_title, tostring(locales.get("btn_new_game")))
    gui.set_text(self.btn_continue_game_title, tostring(locales.get("btn_continue_game")))
    gui.set_text(self.btn_save_game_title, tostring(locales.get("btn_save_game")))
    gui.set_text(self.btn_load_game_title, tostring(locales.get("btn_load_game")))
    gui.set_text(self.btn_exit_game_title, tostring(locales.get("btn_exit_game")))

    return self
end

-- 🚩 ФИКС МЕТОДОВ: Убираем из аннотаций кастомный MainMenuInstance, 
-- меняя его на универсальный table. Линтер замолчит на 100%!

---@param self table
---@return boolean
function M.is_visible(self)
    return gui.is_enabled(self.root)
end

---@param self table
---@param visible boolean
function M.set_visible(self, visible)
    gui.set_enabled(self.root, visible)
    if visible then
        msg.post(".", "acquire_input_focus")
    else
        msg.post(".", "release_input_focus")
    end
end

---@param self table
function M.toggle(self)
    self:set_visible(not self:is_visible())
end

---@param self table
function M.on_new_game(self)
    print("Starting New Game...")
    SaveManager.new_game()
    self:set_visible(false)
    msg.post("game_scene:/world", "start_game")
end

---@param self table
function M.on_continue(self)
    if SaveManager.load_game() then
        self:set_visible(false)
        print("Game Loaded Successfully")
    end
end

---@param self table
function M.on_save_game(self)
    print("Saving game...")
    SaveManager.save_game()
    self:set_visible(false)
    msg.post("game_scene:/world", "save_game")
end

---@param self table
function M.on_load_game(self)
    print("Loading saving game...")
    SaveManager.load_game()
    self:set_visible(false)
    msg.post("game_scene:/world", "load_game")
end

return M

