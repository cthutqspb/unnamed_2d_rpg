local component = require("druid.component")
local locales = require("main.modules.data.locales.locale_manager")

---@class CharacterStats : druid.component
---@field template_id string
local M = component.create("CharacterStats")

function M:init(template_id)
    self.template_id = template_id
    self.root = gui.get_node(template_id .. "/root")
    self.unit = nil

    local function get_node(name)
        return gui.get_node(template_id .. "/" .. name)
    end

    self.nodes = {
        -- keys         
        stamina = get_node("unit_stamina_title"),
        agility = get_node("unit_agility_title"),
        strength = get_node("unit_strength_title"),
        intellect = get_node("unit_intellect_title"),

        -- values
        name = get_node("unit_name_value"),
        race = get_node("unit_race_value"),
        class = get_node("unit_class_value"),
        level = get_node("unit_level_value"),
        health = get_node("unit_health_value")
    }

    -- 🛡️ ЗАЩИТА ТАЙМИНГОВ: Страхуем чтение таблицы статов от nil!
    -- Если бэкенд стейта еще не успел прогрузиться из-за циклического require, 
    -- мы подставляем пустую таблицу. Druid соберет пустой массив нод статов, 
    -- не ломая логику init(), и окно успешно создастся в памяти!
    self.stat_nodes = {}

    self:update_display()
end

---Динамически переключить виджет на рендеринг шмота СОВЕРШЕННО ДРУГОГО существа (WoW-канон!)
---@param unit UnitInstanceData Уникальный строковый UID цели ("player", "c_skeleton_1")
function M:set_inspect_target(unit)
    self.unit = unit
    self:update_display()
end

function M:update_display()
    -- 🛡️ ЗАЩИТА ЭКРАНА: Полностью блокируем отрисовку текста, если бэкенд пустой
    local unit = self.unit

    if not unit or not unit.base_stats or not unit.current_stats then
        return
    end

    if not next(self.stat_nodes) then
        for stat_id, _ in pairs(unit.base_stats) do
            local path = self.template_id .. "/unit_" .. stat_id .. "_value"
            local ok, node = pcall(gui.get_node, path)
            if ok then
                self.stat_nodes[stat_id] = node
            end
        end
    end

    -- keys
    gui.set_text(self.nodes.stamina, locales.get("stat_stamina"))
    gui.set_text(self.nodes.agility, locales.get("stat_agility"))
    gui.set_text(self.nodes.strength, locales.get("stat_strength"))
    gui.set_text(self.nodes.intellect, locales.get("stat_intellect"))

    -- values
    -- Добавляем к строкам or "" или or "0" на случай, если поля паспорта еще пустые
    gui.set_text(self.nodes.name, unit.name or "Unknown")
    gui.set_text(self.nodes.race, unit.race or "human")
    gui.set_text(self.nodes.class, unit.class or "warrior")
    gui.set_text(self.nodes.level, tostring(unit.level or 1))

    local current_health = unit.health or 100
    local maximum_health = unit.max_health or 100
    gui.set_text(self.nodes.health, current_health .. " / " .. maximum_health)

    -- Обновляем только те статы, для которых нашлись ноды в GUI
    for stat_id, node in pairs(self.stat_nodes) do
        local current = unit.current_stats[stat_id] or 0
        local base = unit.base_stats[stat_id] or 0
        local bonus = current - base

        if bonus > 0 then
            gui.set_text(node, current .. " (" .. base .. "+" .. bonus .. ")")
        else
            gui.set_text(node, tostring(current))
        end
    end
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display()
    end
end

return M
