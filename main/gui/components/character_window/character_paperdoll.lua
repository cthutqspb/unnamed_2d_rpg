local component = require("druid.component")
local player_paperdoll = require("main.modules.player_paperdoll")
local items_db = require("main.modules.items_db")
local DragModule = require("main.gui.components.inventory.inventory_drag")

local CharacterPaperdoll = component.create("CharacterPaperdoll")

function CharacterPaperdoll:init(template_id)
    self.template_id = template_id 
    self.druid = self:get_druid()
    self.root = gui.get_node(template_id .. "/root")
    self.slots = {}

    local config = {
        HEAD = "slot_head", CHEST = "slot_chest", LEGS = "slot_legs",
        WEAPON = "slot_main_hand", SHIELD = "slot_off_hand"
    }

    for slot_type, node_id in pairs(config) do
        local path = template_id .. "/" .. node_id
        local slot_root = gui.get_node(path .. "/root")
        
        -- Сами создаем визуальную структуру слота
        self.slots[slot_type] = {
            root = slot_root,
            icon = gui.get_node(path .. "/icon"),
            count = gui.get_node(path .. "/count")
        }

        -- Вешаем Druid-события (Drag) прямо здесь
        local drag = self.druid:new_drag(slot_root, function(ctx, dx, dy)
            -- Передаем управление в общий DragModule только для отрисовки клона
            DragModule.on_item_drag(self, slot_type, dx, dy)
        end)
        
        drag.on_drag_start:subscribe(function()
            local player_paperdoll = require("main.modules.player_paperdoll")
            local item_data = player_paperdoll.slots[slot_type] -- HEAD, WEAPON и т.д.

            if item_data and item_data.item_id then
                self.dragging_slot_type = slot_type -- запоминаем, что тянем с куклы
                DragModule.start_drag_visual(self, item_data.item_id)
                
                -- Скрываем иконку в самом слоте, пока тянем
                gui.set_enabled(self.slots[slot_type].icon, false)
            end
            --DragModule.on_paperdoll_drag_start(self, slot_type)
        end)
        
        drag.on_drag_end:subscribe(function()
            DragModule.on_paperdoll_drag_end(self, slot_type)
        end)
    end
end

function CharacterPaperdoll:on_input(action_id, action)
    DragModule.on_input(self, action_id, action)
end

function CharacterPaperdoll:refresh()
    for slot_type, slot_data in pairs(self.slots) do
        local data = player_paperdoll.slots[slot_type]
        if data and data.item_id then
            local item_cfg = items_db.get_item(data.item_id)
            gui.set_enabled(slot_data.icon, true)
            gui.set_texture(slot_data.icon, item_cfg.texture)
            gui.play_flipbook(slot_data.icon, hash(item_cfg.animation))
            gui.set_color(slot_data.icon, item_cfg.color or vmath.vector4(1))
        else
            gui.set_enabled(slot_data.icon, false)
        end
    end
end

function CharacterPaperdoll:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then self:refresh() end   
end

return CharacterPaperdoll

