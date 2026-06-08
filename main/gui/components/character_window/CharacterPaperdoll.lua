local component = require("druid.component")
local interaction = require("main.modules.interaction")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local items_db = require("main.modules.data.items_db")
local drag_manager = require("main.gui.components.managers.drag_manager")
local CustomCursor = require("main.gui.components.cursor.CustomCursor")

---@class CharacterPaperdollSlot
---@field root node
---@field icon node
---@field amount node

---@class CharacterPaperdoll : druid.component
---@field druid druid.instance
---@field slots table<string, CharacterPaperdollSlot>
---@field root node
---@field template_id string
---@field is_shift_pressed boolean
local M = component.create("CharacterPaperdoll")

---@param template_id string
function M:init(template_id)
    self.template_id = template_id
    self.druid = self:get_druid()
    self.root = gui.get_node(template_id .. "/root")
    self.slots = {}

    -- Конфиг соответствия нод и типов слотов
    local config = {
        HEAD = "slot_head",
        CHEST = "slot_chest",
        LEGS = "slot_legs",
        MAIN_HAND = "slot_main_hand",
        SHIELD = "slot_off_hand"
    }

    for slot_type, node_id in pairs(config) do
        local path = template_id .. "/" .. node_id
        local slot_root = gui.get_node(path .. "/root")

        self.slots[slot_type] = {
            root = slot_root,
            icon = gui.get_node(path .. "/icon"),
            amount = gui.get_node(path .. "/amount")
        }

        self.druid:new_button(slot_root, function()
            self.handle_slot_click(slot_type)
        end)

        local drag = self.druid:new_drag(slot_root)
        ---@diagnostic disable-next-line: inject-field
        drag.drag_threshold = 4 -- Быстрый подцеп

        drag.on_drag_start:subscribe(function()
            ---@type any
            local item_data = player_paperdoll.slots[slot_type]
            if item_data and item_data.item_id then
                ---@type table|nil
                local data = items_db.get_item(item_data.item_id)
                if data then
                    drag_manager.start(self, slot_type, item_data, data)
                    gui.set_enabled(self.slots[slot_type].icon, false)
                    gui.set_enabled(self.slots[slot_type].amount, false)
                end
            end
        end)
    end
end

---@param index string
function M.handle_slot_click(index)
    if interaction.is_double_click(index) then
        local item_data = player_paperdoll.slots[index]

        msg.post(".", "item_action", {
            event = "item_transfer",
            data = {
                from_paperdoll = true,
                item_id = item_data.item_id,
                slot_index = index
            }
        })
    end
end

function M:on_input(action_id, action)
    -- 1. Логика Shift (системная)
    if action_id == hash("key_lshift") then
        if action.pressed then self.is_shift_pressed = true
        elseif action.released then self.is_shift_pressed = false end
    end

    -- 2. Ручной перехват ПКМ (так как Друид его не видит)
    if action_id == hash("mouse_right") and action.released then
        for slot_type, nodes in pairs(self.slots) do
            if gui.pick_node(nodes.root, action.x, action.y) then
                self.handle_right_click(slot_type, action.x, action.y)
            end
        end
    end
end

---@param index string
---@param x number
---@param y number
function M.handle_right_click(index, x, y)
    local item_data = player_paperdoll.slots[index]

    if not item_data or not item_data.item_id then
        print("RIGHT CLICK: Slot is empty")
        return
    end

    local item_cfg = items_db.get_item(item_data.item_id)
    -- -- Проверяем, можно ли разделить этот конкретный стак
    local can_split = item_data.amount and item_data.amount >= 2
    msg.post("main:/context_menu_layer#gui", "show_menu", {
        x = x, y = y,
        type = "gui_item",
        sub_type = item_cfg.type,
        flags = {
            can_split = can_split, -- Передаем флаг в меню
            is_equipped = true
        },
        data = {
            from_paperdoll = true,
            slot_index = index,
            item_id = item_data.item_id,
            source_url = msg.url()
        }
    })

    -- local item_cfg = items_db.get_item(item_data.item_id)
    -- 
    -- -- Проверяем, можно ли разделить этот конкретный стак
    -- local can_split = item_data.amount and item_data.amount >= 2
    -- 
    -- msg.post("main:/context_menu_layer#gui", "show_menu", {
    --     x = x, y = y,
    --     type = "item",
    --     sub_type = item_cfg.type,
    --     can_split = can_split, -- Передаем флаг в меню
    --     data = { 
    --         slot_index = index,
    --         item_id = item_data.item_id,
    --         source_url = msg.url()
    --     }
    -- })
end

---@param x number
---@param y number
---@return boolean
function M:on_drop(x, y)
    if not gui.is_enabled(self.root, true) then return false end

    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, x, y) then
            -- Просто завершаем драг, менеджер сам вызовет can_equip_item у модели
            drag_manager.finish(self, slot_type)
            return true
        end
    end
    return false
end

function M:refresh()
    for slot_type, slot_data in pairs(self.slots) do
        ---@type any
        local data = player_paperdoll.slots[slot_type]
        if data and data.item_id then
            ---@type table|nil
            local item_cfg = items_db.get_item(data.item_id)
            if item_cfg then
                gui.set_enabled(slot_data.icon, true)
                gui.set_texture(slot_data.icon, item_cfg.texture)
                gui.play_flipbook(slot_data.icon, hash(item_cfg.animation or item_cfg.icon))
            end
        else
            gui.set_enabled(slot_data.icon, false)
        end
    end
end

---@param visible boolean
function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then self:refresh() end
end

---@param mx number
---@param my number
---@return table|nil
function M:get_hover_data(mx, my)
    -- 2. Кукла — это СЛОВАРЬ, используем pairs
    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, mx, my) then
            ---@type table|nil
            local item_data = player_paperdoll.slots[slot_type]
            if item_data and item_data.item_id then
                CustomCursor.set_style("cursor_outline_yellow")
                return {
                    type = "gui_item",
                    item = item_data,
                    action_type = item_data.action_type
                }
            end
            CustomCursor.set_style("cursor_default")
        end
    end
end

return M

