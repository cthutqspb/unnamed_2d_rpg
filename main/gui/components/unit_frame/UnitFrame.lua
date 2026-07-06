local component = require("druid.component")
local locales = require("main.modules.data.locales.locale_manager")
local HealthBar = require("main.gui.components.health_bar.HealthBar")
local ResourceBar = require("main.gui.components.resource_bar.ResourceBar")
local units_state = require("main.modules.game_state.units_state")

---@class UnitFrame : druid.component
---@field unit_health_bar HealthBar Кастомный компонент полоски ХП
---@field unit_resource_bar ResourceBar Кастомный компонент полоски ресурса
---@field unit_name node Текстовая нода имени существа
---@field unit_level node Текстовая нода уровня существа
---@field root node
local M = component.create("UnitFrame")

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

function M:init(template_id)
    self.druid = self:get_druid()
    self.template_id = template_id

    -- Инициализируем полоски Друида через универсальные шаблоны
    self.unit_health_bar = self.druid:new(HealthBar, get_id(template_id, "health_bar"))
    self.unit_resource_bar = self.druid:new(ResourceBar, get_id(template_id, "resource_bar"))

    -- Находим ноды текста и корня
    self.root = gui.get_node(get_id(template_id, "root"))
    self.unit_name = gui.get_node(get_id(template_id, "unit_name"))
    self.unit_level = gui.get_node(get_id(template_id, "unit_level"))

    gui.set_enabled(self.root, false)
end

---🎯 МОНОЛИТНАЯ СИНХРОНИЗАЦИЯ: Слепо перерисовать фрейм по входящему UID из RAM
---@param uid string|nil Уникальный Си-ИНН существа вселенной ("player", "c_1234")
function M:refresh_frame(uid)
    -- Жесткий гвард: если ХУД не передал айдишник — гасим фрейм с экрана
    if not uid or uid == "" then
        gui.set_enabled(self.root, false)
        return
    end

    -- 🧠 ЧИТАЕМ ИСТИННЫЙ СТEЙТ ИЗ ЦЕНТРАЛЬНОГО РЕЕСТРА ПО ВХОДЯЩЕМУ UID:
    local unit = units_state.get(uid)
    if not unit or unit.combat.is_dead then
        gui.set_enabled(self.root, false)
        return
    end

    -- Включаем визуал рамки, раз существо живо и валидно в RAM
    gui.set_enabled(self.root, true)

    -- 1. Считаем и красим ХП-бар существа
    local health_percent = unit.health_resource.current / unit.health_resource.max
    self.unit_health_bar:update_health(health_percent)

    -- 2. Достаем нашу изолированную доменную табличку ресурса из RAM
    local resource = unit.resource

    -- ЧИСТОЕ ПРЯМОЕ ЧТЕНИЕ ИЗ ОБЪЕКТА:
    local current_resource_value = resource and resource.current or 0
    local max_resource_value = resource and resource.max or 100
    local resource_percent = current_resource_value / max_resource_value

    -- 🚀 СКАРМЛИВАЕМ НАШЕМУ УНИВЕРСАЛЬНОМУ RESOURCE_BAR:
    if self.unit_resource_bar and self.unit_resource_bar.update_resource then
        self.unit_resource_bar:update_resource(resource and resource.type or "mana", resource_percent)
    end

    -- 3. Выплескиваем паспортные текстовые данные в ноды экрана
    -- (Здесь локали подхватят locales.get(unit.identity.name_key) позже)
    gui.set_text(self.unit_name, locales.get(unit.identity.name_key) or "Unknown")
    gui.set_text(self.unit_level, string.format("Ур. %d", unit.level or 1))
end

return M

