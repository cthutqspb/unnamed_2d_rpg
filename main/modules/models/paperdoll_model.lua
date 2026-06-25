local items_db = require("main.modules.data.items_db")
local item_requirements_manager = require("main.modules.logic.item_requirements_manager")

---@class Item
---@field item_id hash|string|nil
---@field amount integer
---@field uid string|nil

---@class PaperdollInstance
---@field slots table<string, Item>
---@field owner table|nil
local M = {}
M.__index = M

---@return PaperdollInstance
function M.new(owner)
    local instance = setmetatable({}, M)

    instance.owner = owner

    instance.slots = {
        HEAD = {item_id = nil, amount = 0, uid = nil},
        CHEST = {item_id = nil, amount = 0, uid = nil},
        LEGS = {item_id = nil, amount = 0, uid = nil},
        MAIN_HAND = {item_id = nil, amount = 0, uid = nil},
        SHIELD = {item_id = nil, amount = 0, uid = nil}
    }

    return instance
end

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

---@param item Item Требуемый предмет
---@param slot_type string Слот экипировки
---@return boolean
function M:can_equip_item(item, slot_type) -- 🛡️ ИСПРАВЛЕНО: УБРАЛИ unit_data! Сигнатура чиста!
    if not self.slots[slot_type] or not item.item_id then
        return false
    end

    local cfg = items_db.get_item(item.item_id)
    if not cfg or cfg.equip_slot ~= slot_type then
        return false
    end

    -- 🦾 ЗРЯЧИЙ ЮНИТ-КАНОН: Кукла сама берет паспорт своего хозяина из своего поля self.owner!
    local unit_data = self.owner
    if not unit_data then return false end

    ---@type RequirementResult
    local check = item_requirements_manager.check(cfg, unit_data, item)
    if not check.is_ok then
        if unit_data.is_player then
            print("CANNOT EQUIP: " .. (check.reason or "low stats"))
        end
        return false
    end

    return true
end

--@return table<string, Item>
function M:get_save_data()
    return self.slots
end

---@param data table<string, Item>
function M:load_save_data(data)
    self:clear()
    if not data then return end

    for slot_type, slot_data in pairs(data) do
        local current_slot = self.slots[slot_type]
        if current_slot and slot_data.item_id then
            local id = slot_data.item_id

            if type(id) == "string" then
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

function M:clear()
    for _, slot in pairs(self.slots) do
        slot.item_id = nil
        slot.amount = 0
        slot.uid = nil
    end
end

return M

