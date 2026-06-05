local component = require("druid.component")
local HealthBar = require("main.gui.components.health_bar.HealthBar")
local ManaBar = require("main.gui.components.mana_bar.ManaBar")


---@class PlayerFrame : druid.component
---@field player_health_bar HealthBar Кастомный компонент полоски ХП
---@field player_mana_bar ManaBar Кастомный компонент полоски маны
---@field player_name node Текстовая нода имени монстра
---@field player_level node Текстовая нода уровня монстра
---@field root node
local M = component.create("PlayerFrame")

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

function M:init(template_id)
    self.druid = self:get_druid()
    self.template_id = template_id
    -- Получаем узлы из GUI-шаблона

    self.player_health_bar = self.druid:new(HealthBar, get_id(template_id, "health_bar"))
    self.player_mana_bar = self.druid:new(ManaBar, get_id(template_id, "mana_bar"))
    self.player_name = gui.get_node("player_frame/player_name")
    self.player_level = gui.get_node("player_frame/player_level")
    self.root = gui.get_node("player_frame/root")
    gui.set_enabled(self.root, true)
end

function M:on_player_event(message_id, message)
    if message_id == hash("update_health_deferred") then
        self.player_health_bar:update_health(message.percentage)
    end

    if message_id == hash("update_mana_deferred") then
        self.player_mana_bar:update_mana(message.percentage)
    end
end

return M
