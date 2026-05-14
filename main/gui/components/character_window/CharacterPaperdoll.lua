local component = require("druid.component")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local items_db = require("main.modules.data.items_db")
local drag_manager = require("main.gui.components.managers.drag_manager")
local tooltip_manager = require("main.gui.components.managers.tooltip_manager")

---@class CharacterPaperdoll : druid.component
---@field druid table
---@field slots table
---@field root any
---@field template_id string
local M = component.create("CharacterPaperdoll")

function M:init(template_id)
    self.template_id = template_id
    self.druid = self:get_druid()
    self.root = gui.get_node(template_id .. "/root")
    self.slots = {}

    self.refresh = M.refresh
    -- Конфиг соответствия нод и типов слотов
    local config = {
        HEAD = "slot_head",
        CHEST = "slot_chest",
        LEGS = "slot_legs",
        WEAPON = "slot_main_hand",
        SHIELD = "slot_off_hand"
    }

    for slot_type, node_id in pairs(config) do
        local path = template_id .. "/" .. node_id
        local slot_root = gui.get_node(path .. "/root")

        self.slots[slot_type] = {
            root = slot_root,
            icon = gui.get_node(path .. "/icon"),
            count = gui.get_node(path .. "/count")
        }

        local drag = self.druid:new_drag(slot_root)

        drag.on_drag_start:subscribe(function()
            local item_data = player_paperdoll.slots[slot_type]
            if item_data and item_data.item_id then
                local data = items_db.get_item(item_data.item_id)
                if data then
                    drag_manager.start(self, slot_type, item_data, data)
                    gui.set_enabled(self.slots[slot_type].icon, false)
                end
            end
        end)
    end
end

function M:on_drop(x, y)
    local d = drag_manager.get_active()
    if not d or not d.item then return false end

    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, x, y) then
            local item_cfg = items_db.get_item(d.item.item_id)

            -- ПРОВЕРКА: используем 'type' из items_db
            if item_cfg and item_cfg.type == slot_type then
                print("Paperdoll: Equipping " .. tostring(d.item.item_id) .. " to " .. slot_type)
                drag_manager.finish(self, slot_type)
                return true
            else
                local got_type = item_cfg and item_cfg.type or "nil"
                print("Paperdoll: Invalid type! Need " .. slot_type .. ", got " .. got_type)
                return false
            end
        end
    end
    return false
end

function M:get_data_source()
    return player_paperdoll
end

function M:refresh()
    for slot_type, slot_data in pairs(self.slots) do
        local data = player_paperdoll.slots[slot_type]
        if data and data.item_id then
            local item_cfg = items_db.get_item(data.item_id)
            if item_cfg then
                gui.set_enabled(slot_data.icon, true)
                gui.set_texture(slot_data.icon, item_cfg.texture)
                gui.play_flipbook(slot_data.icon, hash(item_cfg.animation))
            end
        else
            gui.set_enabled(slot_data.icon, false)
        end
    end
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then self:refresh() end
end

function M:update_hover(mx, my)
    -- Проверяем, включена ли нода и вся цепочка её родителей
    if not self.root or not gui.is_enabled(self.root, true) then
        return false
    end
    -- 1. Проверка для словаря (HEAD, CHEST...)
    if not self.slots or next(self.slots) == nil then return false end

    if drag_manager.is_dragging() then
        tooltip_manager.hide()
        return false
    end

    local hovered = false
    -- 2. Кукла — это СЛОВАРЬ, используем pairs
    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, mx, my) then
            local item_data = self:get_data_source().slots[slot_type]

            if item_data and item_data.item_id then
                tooltip_manager.show("item", item_data.item_id)
            else
                tooltip_manager.hide()
            end
            hovered = true
            break
        end
    end
    return hovered
end


return M

