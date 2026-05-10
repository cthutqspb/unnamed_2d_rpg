local component = require("druid.component")

local HealthBar = component.create("health_bar")

function HealthBar:init()
    -- Получаем узлы из шаблона
    self.fill = gui.get_node("health_bar/fill")
     self.max_width = gui.get_size(self.fill).x
    
    -- Устанавливаем начальное значение
    self:update_health(1.0)
end

function HealthBar:update_health(percentage)
    percentage = math.max(0, math.min(1, percentage or 0))
    local target_width = self.max_width * percentage
    
    -- Анимация размера
     gui.animate(self.fill, gui.PROP_SIZE, vmath.vector3(target_width, gui.get_size(self.fill).y, 0), gui.EASING_OUTSINE, 0.3)
    
    -- Цвет (зелёный -> жёлтый -> красный)
    local color = vmath.vector4(0, 1, 0, 1)
    if percentage < 0.3 then 
        color = vmath.vector4(1, 0, 0, 1)
    elseif percentage < 0.6 then 
        color = vmath.vector4(1, 1, 0, 1) 
    end
    gui.set_color(self.fill, color)
end

return HealthBar
