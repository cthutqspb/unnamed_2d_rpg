local component = require("druid.component")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")

---@class ActionBar : druid.component
---@field template_id string
---@field static_grid StaticGrid
local M = component.create("ActionBar")

---@private
---@param template_id string
---@param node_name string
---@return string
local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

---@param template_id string
---@param config table
function M:init(template_id, config)
    self.template_id = template_id
    local druid = self:get_druid()

    self.static_grid = druid:new(StaticGrid, get_id(template_id, "static_grid"), {
        columns = config.columns or 12,
        rows = config.rows or 1,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2,
        on_click = config.on_click
    })
    -- gui.set_visible(self.static_grid)
end

return M
