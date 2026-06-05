local component = require("druid.component")
local layout = require("druid.extended.layout") -- Проверь путь в Assets

---@class MenuBar : druid.component
local M = component.create("MenuBar")

function M:init(template_id)
    self.template_id = template_id or "menu_bar"
    local d = self:get_druid()

    local container_id = self.template_id .. "/container"

    -- 1. Создаем Layout (тип "horizontal" строкой, как в примере)
    self.layout = d:new(layout, container_id, "horizontal")
    self.layout.is_resize_width = true
    self.layout.is_resize_height = true
    -- 2. Настраиваем отступы (padding и margin)
    -- Согласно примеру, set_margin принимает (x, y)
    self.layout:set_padding(4, 4, 4, 4)
    self.layout:set_margin(4, 4)

    -- 3. Список кнопок
    local buttons = {
        "button_inventory",
        "button_character"
    }

    for _, id in ipairs(buttons) do
        local path = self.template_id .. "/" .. id .. "/root"
        local node = gui.get_node(path)

        d:new_button(node, function()

        if id == "button_inventory" then
            msg.post(".", "toggle_inventory") -- "." означает "отправить скрипту этого же объекта"
        end
        if id == "button_character" then
            msg.post(".", "toggle_character") -- "." означает "отправить скрипту этого же объекта"
        end

    end)

        -- Добавляем в Layout
        self.layout:add(node)
    end

    -- 4. ВАЖНО: Вызываем метод обновления из примера!
    self.layout:refresh_layout()
end

function M:visual_push(button_id)
    -- Если у нас есть ссылка на кнопку, мы можем заставить её "нажаться"
    -- Но проще всего вызвать функцию клика напрямую через сообщение
end

return M
