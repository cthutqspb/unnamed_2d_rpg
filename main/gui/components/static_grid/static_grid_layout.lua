local items_db = require("main.modules.data.items_db")
local M = {}

function M.create_slots(self)
    self.slots = {}
    local base_path = self.template_id .. "/slot_prefab"
    local prefab_root = gui.get_node(base_path .. "/root")

    local path_root  = hash(base_path .. "/root")
    local path_icon  = hash(base_path .. "/icon")
    local path_count = hash(base_path .. "/count")

    for i = 1, self.columns * self.rows do
        local nodes = gui.clone_tree(prefab_root)
        local slot_root = nodes[path_root]

        gui.set_enabled(slot_root, true)
        gui.set_parent(slot_root, self.container)
        gui.set_position(slot_root, vmath.vector3(0, 0, 0))

        self.grid:add(slot_root)

        table.insert(self.slots, {
            root = slot_root,
            icon = nodes[path_icon],
            count = nodes[path_count]
        })
    end
end

function M.draw_slot(self, index, item_id, amount)
    local slot = self.slots[index]
    if not slot then return end

    local data = items_db.get_item(item_id)
    if data then
        gui.set_enabled(slot.icon, true)
        gui.set_color(slot.icon, data.color or vmath.vector4(1, 1, 1, 1))
        if data.texture then gui.set_texture(slot.icon, data.texture) end
        gui.play_flipbook(slot.icon, hash(data.animation or data.icon))

        local is_stack = amount and amount > 1
        gui.set_enabled(slot.count, is_stack)
        if is_stack then gui.set_text(slot.count, tostring(amount)) end
    end
end

function M.clear_slot_visual(self, index)
    local slot = self.slots[index]
    if slot then
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.count, false)
    end
end

return M


