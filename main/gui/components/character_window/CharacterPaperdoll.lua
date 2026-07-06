local component = require("druid.component")
local interactions = require("main.modules.interactions")
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
---@field unit UnitInstance 🚩 Текущая зрячая цель, чью куклу мы рендерим на экране
local M = component.create("CharacterPaperdoll")

---@param template_id string
function M:init(template_id)
    self.template_id = template_id
    self.druid = self:get_druid()
    self.root = gui.get_node(template_id .. "/root")
    self.slots = {}
    self.unit = nil

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
            self:handle_slot_click(slot_type)
        end)

        local drag = self.druid:new_drag(slot_root)
        ---@diagnostic disable-next-line: inject-field
        drag.drag_threshold = 4 -- Быстрый подцеп

        drag.on_drag_start:subscribe(function()
            if not self.unit or not self.unit.paperdoll then return end

            local item = self.unit.paperdoll:get_item(slot_type)
            if item and item.item_id then
                local data = items_db.get_item(item.item_id)
                if data then
                    drag_manager.start(self.unit.paperdoll, slot_type, item, data)

                    gui.set_enabled(self.slots[slot_type].icon, false)
                    gui.set_enabled(self.slots[slot_type].amount, false)
                end
            end
        end)
    end
end

---Динамически переключить виджет на рендеринг шмота СОВЕРШЕННО ДРУГОГО существа (WoW-канон!)
---@param unit UnitInstance Уникальный строковый UID цели ("player", "c_skeleton_1")
function M:set_inspect_target(unit)
    self.unit = unit
    self:refresh()
end

---Прослойка-мост для drag_manager (Вызывается менеджером перетаскивания автоматически)
---@param item Item
---@param slot_type string
---@return boolean
function M:can_equip_item(item, slot_type)
    if not self.unit or not self.unit.paperdoll then return false end

    return self.unit.paperdoll:can_equip_item(item, slot_type)
end

---@param slot_type string
function M:handle_slot_click(slot_type)
    if interactions.is_double_click(slot_type) then
        if not self.unit or not self.unit.paperdoll then return end

        local item = self.unit.paperdoll:get_item(slot_type)
        if not item then return end

        msg.post(".", "item_action", {
            event = "item_transfer",
            data = {
                from_paperdoll = true,
                item_id = item.item_id,
                slot_index = slot_type,
                unit_uid = self.unit.uid, -- Прокидываем UID в диспетчер, чтобы он знал, чью куклу раздевают!
            }
        })
    end
end

---@param slot_type string
---@param x number
---@param y number
function M:handle_right_click(slot_type, x, y)
    if not self.unit or not self.unit.paperdoll then return end

    local item = self.unit.paperdoll:get_item(slot_type)
    if not item or not item.item_id then
        return
    end

    local item_cfg = items_db.get_item(item.item_id)

    if not item_cfg then return end

    local can_split = item.amount and item.amount >= 2

    msg.post("main:/context_menu_layer#gui", "show_menu", {
        x = x, y = y,
        type = "gui_item",
        sub_type = item_cfg.type,
        flags = {
            can_split = can_split,
            is_equipped = true
        },
        data = {
            from_paperdoll = true,
            slot_index = slot_type,
            item_id = item.item_id,
            source_url = msg.url(),
            unit_uid = self.unit.uid -- Прокидываем UID в контекстное меню!
        }
    })
end

function M:on_input(action_id, action)
    if action_id == hash("key_lshift") then
        if action.pressed then self.is_shift_pressed = true
        elseif action.released then self.is_shift_pressed = false end
    end

    if action_id == hash("mouse_right") and action.released then
        for slot_type, nodes in pairs(self.slots) do
            if gui.pick_node(nodes.root, action.x, action.y) then
                -- 🛡️ ИСПРАВЛЕНО: Вызываем через двоеточие!
                self:handle_right_click(slot_type, action.x, action.y)
            end
        end
    end
end

---@param x number
---@param y number
---@return boolean
function M:on_drop(x, y)
    if not gui.is_enabled(self.root, true) then return false end

    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, x, y) then
            if self.unit and self.unit.paperdoll then
                -- 🦾 Передаем strictly модель куклы!
                drag_manager.finish(self.unit.paperdoll, slot_type)
                return true
            end
        end
    end
    return false
end

function M:refresh()
    if not self.unit or not self.unit.paperdoll then return false end

    for slot_type, slot in pairs(self.slots) do
        -- 🦾 ЧИТАЕМ ИЗ RAM ПАСПОРТА ТЕКУЩЕГО ЮНИТА:
        local data = self.unit.paperdoll:get_item(slot_type)
        if data and data.item_id then
            local item_cfg = items_db.get_item(data.item_id)
            if item_cfg then
                gui.set_enabled(slot.icon, true)
                gui.set_texture(slot.icon, item_cfg.texture)
                gui.play_flipbook(slot.icon, hash(item_cfg.animation))
            end
        else
            gui.set_enabled(slot.icon, false)
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
    if not self.unit or not self.unit.paperdoll then return end

    for slot_type, nodes in pairs(self.slots) do
        if gui.pick_node(nodes.root, mx, my) then
            -- 🦾 ЧИТАЕМ ИЗ RAM ПАСПОРТА ТЕКУЩЕГО ЮНИТА:
            local item = self.unit.paperdoll:get_item(slot_type)
            if item and item.item_id then
                CustomCursor.set_style("cursor_outline_yellow")
                return {
                    type = "gui_item",
                    item = item,
                    action_type = item.action_type
                }
            end
            CustomCursor.set_style("cursor_default")
        end
    end
end

return M
