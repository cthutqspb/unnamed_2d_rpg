local component = require("druid.component")
local BaseWindow = require("main.gui.components.base_window.base_window")
local locales = require("main.modules.data.locales.locale_manager")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")

---@class InventoryWindow : druid.component
---@field static_grid StaticGrid
local M = component.create("InventoryWindow")

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

function M:init(template_id, player_inventory)
    local d = self:get_druid()

    BaseWindow.init(self, template_id, {
        on_show = function ()
            M.refresh(self)
        end
    })

    self.toggle = BaseWindow.toggle
    self.is_visible = BaseWindow.is_visible
    self.set_visible = BaseWindow.set_visible
    self.close = BaseWindow.close
    self.set_title  = BaseWindow.set_title
    self.update = BaseWindow.update
    self.is_over_window = BaseWindow.is_over_window
    self.handle_hover = BaseWindow.handle_hover


    config = config or {}
    -- local d = self:get_druid()

    self.static_grid = d:new(StaticGrid, get_id(template_id, "static_grid"), {
        data_source = player_inventory,
        columns = config.columns or 6,
        rows = config.rows or 4,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2
    })

    --local title_node = gui.get_node(template_id .. "/title")
    self.set_title(self, locales.get('inventory_title'))
    self:set_visible(false)
    -- local screen_w = sys.get_config("display.width")
    -- local screen_h = sys.get_config("display.height")
    -- local inv_size = gui.get_size(self.root)
    -- local target_x = screen_w - (inv_size.x / 2) - 20
    -- local target_y = 60 + (inv_size.y / 2)

    -- if config.bg_color then
    --     if self.body then
    --         gui.set_color(self.background, config.bg_color)
    --     end
    -- end

    -- gui.set_position(self.root, vmath.vector3(target_x, target_y, 0))

end

function M:refresh()
    self.static_grid:refresh()
end

-- function M:on_input(action_id, action)
--     if self.static_grid then
--         self.static_grid:on_input(action_id, action)
--     end
-- end

function M:get_slot_at_position(x, y)
    if self.static_grid then
        return self.static_grid:get_slot_at_position(x, y)
    end
    return nil
end

-- function M:set_visible(visible)
--     gui.set_enabled(self.root, visible)
--     if visible and self.static_grid then
--         self.static_grid:refresh()
--     end
-- end

-- function M:set_visible(visible)
--     gui.set_enabled(self.root, visible)
--     if visible then
--         -- Как только окно становится видимым — принудительно обновляем данные
--         self.static_grid:refresh() 
--     end
-- end


return M
