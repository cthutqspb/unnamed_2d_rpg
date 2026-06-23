local component = require("druid.component")

---@class HealthBar : druid.component
---@field fill node Узел внутренней заливки полоски здоровья (Box-node)
local M = component.create("HealthBar")

---Инициализация компонента полоски здоровья персонажа
---@param fill_node_or_id string|node Строковый ID шаблона ИЛИ уже готовая нода fill
function M:init(fill_node_or_id)
    
    if type(fill_node_or_id) == "string" then
        -- Старый вариант (для обратной совместимости, если где-то остался статичный UI)
        self.fill = gui.get_node(fill_node_or_id .. "/fill")
    else
        -- Наш новый бронебойный вариант: просто сохраняем переданную ноду
        self.fill = fill_node_or_id
    end

    -- Устанавливаем дефолтное начальное значение на полный столб жизни
    self:update_health(1.0)
end

---Плавно обновить визуальное отображение полоски здоровья (масштаб и цвет)
---@param percentage number Текущий процент ХП в диапазоне от 0.0 до 1.0
function M:update_health(percentage)
    -- Защита от выхода за границы диапазона
    percentage = math.max(0.0, math.min(1.0, percentage or 0.0))

    -- ПЛАВНАЯ АНИМАЦИЯ МАСШТАБА (WoW-канон):
    gui.animate(self.fill, "scale.x", percentage, gui.EASING_OUTSINE, 0.3)

    -- ДИНАМИЧЕСКИЙ ЦВЕТ (зелёный -> жёлтый -> красный)
    local color = vmath.vector4(0.0, 1.0, 0.0, 1.0)

    if percentage < 0.3 then
        color = vmath.vector4(1.0, 0.0, 0.0, 1.0)
    elseif percentage < 0.6 then
        color = vmath.vector4(1.0, 1.0, 0.0, 1.0)
    end

    gui.set_color(self.fill, color)
end

function M:set_visible(visible)
    local root = gui.get_parent(self.fill)
    if root then
        gui.set_enabled(root, visible)
    end
end

return M

