local locales = require("main.modules.data.locales.locale_manager")
local component = require("druid.component")
local HealthBar = require("main.gui.components.health_bar.HealthBar")

---@class NameplateInstance : druid.component
---@field nameplate_instance_name node
---@field nameplate_instance_health_bar HealthBar 
local M = component.create("NameplateInstance")

function M:init(root_node, cloned_nodes)
    self.druid = self:get_druid()

    -- Текст имени (обычно лежит в корне, поэтому просто "plate_name")
    -- Если он тоже внутри шаблона, то будет hash("имя_шаблона/plate_name")
    self.nameplate_instance_name = cloned_nodes[hash("plate_name")] or cloned_nodes[hash("health_bar/plate_name")]

    -- Полоска здоровья (ищем с учетом префикса шаблона)
    local fill_node = cloned_nodes[hash("health_bar/fill")]

    -- На всякий случай страховка: если шаблона не было и fill лежал в корне
    if not fill_node then
        fill_node = cloned_nodes[hash("fill")]
    end

    -- Проверяем, что ноду мы точно нашли перед тем, как совать в Druid
    if not fill_node then
        print("❌ КРИТИЧЕСКАЯ ОШИБКА: Нода заливки не найдена ни по одному хэшу!")
    end

    self.nameplate_instance_health_bar = self.druid:new(HealthBar, fill_node)
end


---🎯 ТВОЙ РЕАКТИВНЫЙ АПДЕЙТ СТЕЙТА (Оставляем без изменений):
function M:update_state(unit_instance_data)
    if not unit_instance_data then return end

    local health_percent = unit_instance_data.health / unit_instance_data.max_health
    self.nameplate_instance_health_bar:update_health(health_percent)

    if unit_instance_data.is_dead then
        local dead_text = locales.get(unit_instance_data.name_key) .. " (" .. locales.get("unit_dead_suffix") .. ")"

        self.nameplate_instance_health_bar:set_visible(false)
        gui.set_text(self.nameplate_instance_name, dead_text)
    end
end

return M


