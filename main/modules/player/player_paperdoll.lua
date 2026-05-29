local items_db = require("main.modules.data.items_db")
local item_requirements_manager = require("main.modules.logic.item_requirements_manager")
local character_data = require("main.modules.character.character_data")

---@class Item
---@field item_id hash|string|nil
---@field amount integer
---@field uid string|nil

---@class Paperdoll
local M = {}

---@type table<string, Item>
M.slots = {
    HEAD = {item_id = nil, amount = 0, uid = nil},
    CHEST = {item_id = nil, amount = 0, uid = nil},
    LEGS = {item_id = nil, amount = 0, uid = nil},
    MAIN_HAND = {item_id = nil, amount = 0, uid = nil},
    SHIELD = {item_id = nil, amount = 0, uid = nil}
}

-- ИНТЕРФЕЙСНЫЕ МЕТОДЫ (Используем self для доступа к данным)

---@param slot_type string
---@return Item|nil
function M:get_item(slot_type)
    local slot = self.slots[slot_type]
    if not slot or not slot.item_id then
        return nil
    end
    return slot
end

---@param slot_type string
---@param item_data Item|nil
function M:set_item(slot_type, item_data)
    if not item_data or not item_data.item_id then
        self.slots[slot_type] = { item_id = nil, amount = 0, uid = nil }
    else
        self.slots[slot_type] = {
            item_id = item_data.item_id,
            amount = math.floor(item_data.amount or 1),
            uid = item_data.uid
        }
    end
end

---@param item Item
---@param slot_type string
---@return boolean
function M:can_equip_item(item, slot_type)
    if not self.slots[slot_type] or not item.item_id then
        return false
    end

    local cfg = items_db.get_item(item.item_id)
    if not cfg or cfg.equip_slot ~= slot_type then
        return false
    end

    ---@type RequirementResult
    local check = item_requirements_manager.check(cfg, character_data.player, item)
    if not check.is_ok then
        print("CANNOT EQUIP: " .. (check.reason or "low stats"))
        return false
    end

    return true
end

-- СИСТЕМНЫЕ МЕТОДЫ (Оставил через точку, так как они работают с модулем напрямую)

---@return table<string, Item>
function M.get_save_data()
    return M.slots
end

---@param data table<string, Item>
function M.load_save_data(data)
    M.clear()
    if not data then return end

    for slot_type, slot_data in pairs(data) do
        local current_slot = M.slots[slot_type]
        if current_slot and slot_data.item_id then
            local id = slot_data.item_id

            -- Если пришла строка (из JSON), чистим её и хешируем
            if type(id) == "string" then
                -- Убираем обертку "hash: [item_id]", если она есть
                id = id:match("%[(.-)%]") or id
                current_slot.item_id = hash(id)
            else
                current_slot.item_id = id
            end

            current_slot.amount = math.floor(slot_data.amount or 0)
            current_slot.uid = slot_data.uid
        end
    end
end


function M.clear()
    for _, slot in pairs(M.slots) do
        slot.item_id = nil
        slot.amount = 0
        slot.uid = nil
    end
end

return M

