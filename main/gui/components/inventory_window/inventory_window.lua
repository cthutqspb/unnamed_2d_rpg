local component = require("druid.component")
local strings = require("main.modules.data.strings")
local InventoryGrid = require("main.gui.components.inventory_grid.InventoryGrid")

local M = {}

function M.new(druid, template_id, player_inventory)

    local function get_id(node_name)
        if not template_id or template_id == "" then
            return node_name 
        end
        return template_id .. "/" .. node_name
    end

    config = config or {}
    -- local d = self:get_druid()

    local self = {
        -- druid = druid,
        -- template_id = template_id,
        root = gui.get_node("root"),
        header = gui.get_node("header"),
        btn_close = gui.get_node("btn_close"),
        container = gui.get_node("container"),  -- пустой контейнер
        background = gui.get_node('background'),
        title = gui.get_node("title")
    }

    self.set_visible = M.set_visible
    self.toggle = M.toggle
    self.is_visible = M.is_visible
    self.close = M.close

    self.inventory_grid = druid:new(InventoryGrid, get_id("inventory_grid"), {
        data_source = config.data_source,
        columns = config.columns or 6,
        rows = config.rows or 4,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2
    })

    --local title_node = gui.get_node(template_id .. "/title")
    gui.set_text(self.title, strings.get("inventory_title"))

    local screen_w = sys.get_config("display.width")
    local screen_h = sys.get_config("display.height")
    local inv_size = gui.get_size(self.root)
    local target_x = screen_w - (inv_size.x / 2) - 20
    local target_y = 60 + (inv_size.y / 2)

    if config.bg_color then
        if self.background then
            gui.set_color(self.background, config.bg_color)
        end
    end

    gui.set_position(self.root, vmath.vector3(target_x, target_y, 0))

    self.drag = druid:new_drag(self.header, function(context, dx, dy)
        local pos = gui.get_position(self.root)
        pos.x = pos.x + dx
        pos.y = pos.y + dy
        gui.set_position(self.root, pos)
    end)

    self.drag.is_touch_threshold = true

    druid:new_button(self.btn_close, function()
        self:set_visible(false)
    end)
    -- self:refresh()
    -- msg.post("@render:", "acquire_input_focus")
    if self.inventory_grid then
        self.inventory_grid:refresh()
    end
    return self
end

function M:refresh()
    print("=== InventoryGrid:refresh called ===")
    if self.inventory_grid then
        self.inventory_grid:refresh()
    end
end

function M:on_input(action_id, action)
    if self.inventory_grid then
        self.inventory_grid:on_input(action_id, action)
    end
end

function M:get_slot_at_position(x, y)
    if self.inventory_grid then
        return self.inventory_grid:get_slot_at_position(x, y)
    end
    return nil
end

function M:is_visible()
    return gui.is_enabled(self.root)
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible and self.inventory_grid then
        self.inventory_grid:refresh()
    end
end

function M:close()
    self:set_visible(false)
end

-- function M:set_visible(visible)
--     gui.set_enabled(self.root, visible)
--     if visible then
--         -- Как только окно становится видимым — принудительно обновляем данные
--         self.inventory_grid:refresh() 
--     end
-- end

function M:toggle()
    local current = gui.is_enabled(self.root)
    self:set_visible(not current)
end

return M
