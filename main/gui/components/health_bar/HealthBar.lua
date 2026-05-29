local component = require("druid.component")

---@class HealthBar : druid.component
---@field fill node Узел внутренней заливки полоски здоровья (Box-node)
---@field max_width number Максимальная физическая ширина полоски в пикселях (при 100% ХП)
local M = component.create("HealthBar")

---Инициализация компонента полоски здоровья персонажа
function M:init()
    -- Получаем узлы из GUI-шаблона
    self.fill = gui.get_node("health_bar/fill")
    self.max_width = gui.get_size(self.fill).x

    -- Устанавливаем дефолтное начальное значение на полный столб жизни
    self:update_health(1.0)
end

---Плавно обновить визуальное отображение полоски здоровья (размер и цвет)
---@param percentage number Текущий процент ХП в диапазоне от 0.0 до 1.0
function M:update_health(percentage)
    -- Защита от выхода за границы диапазона
    percentage = math.max(0.0, math.min(1.0, percentage or 0.0))

    -- Вычисляем целевую логическую ширину ноды в пикселях
    local target_width = self.max_width * percentage
    print("HEALTH WIDTH", target_width)

    -- 🎯 ПЛАВНАЯ АНИМАЦИЯ: Изменяем размер ноды. 
    -- Используем плоский тип vector3 в аннотации, чтобы линтер не ругался на vmath
    ---@type vector3
    local target_size = vmath.vector3(target_width, gui.get_size(self.fill).y, 0.0)

    gui.animate(self.fill, gui.PROP_SIZE, target_size, gui.EASING_OUTSINE, 0.3)

    -- 🎨 ДИНАМИЧЕСКИЙ ЦВЕТ (зелёный -> жёлтый -> красный)
    ---@type vector4
    local color = vmath.vector4(0.0, 1.0, 0.0, 1.0)

    if percentage < 0.3 then
        color = vmath.vector4(1.0, 0.0, 0.0, 1.0)
    elseif percentage < 0.6 then
        color = vmath.vector4(1.0, 1.0, 0.0, 1.0)
    end

    gui.set_color(self.fill, color)
end

return M

