local items_db = require("main.modules.data.items_db")
local unit_logic = require("main.modules.unit.logic.unit_logic")

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
---@param item Item|nil
function M:set_item(slot_type, item)
    print("➡️ МУТАЦИЯ: self.slots адрес =", self.slots)
    if not item or not item.item_id then
        print("⚠️ БЭКЕНД: Кто-то принудительно ОБНУЛИЛ слот куклы:", slot_type)
        self.slots[slot_type] = { item_id = nil, amount = 0, uid = nil }
    else
        self.slots[slot_type] = {
            item_id = item.item_id,
            amount = math.floor(item.amount or 1),
            uid = item.uid
        }
    end
    print("SLOT", slot_type, self.slots[slot_type].item_id)
end

---@param item Item Требуемый предмет
---@param slot_type string Слот экипировки
---@return boolean
function M:can_equip_item(item, slot_type)
    if not self.slots[slot_type] or not item.item_id then
        return false
    end

    local cfg = items_db.get_item(item.item_id)
    if not cfg or cfg.equip_slot ~= slot_type then
        return false
    end

    -- 🦾 ЗРЯЧИЙ ЮНИТ-КАНОН: Кукла сама берет паспорт своего хозяина из своего поля self.owner!
    ---@type UnitInstance
    local unit = self.owner
    if not unit then return false end

    ---@type RequirementResult
    local check_result = unit_logic.check_item_requirements(cfg, unit)

    if not check_result.is_ok then
        if unit.is_player then
            print("CANNOT EQUIP: " .. (check_result.reason or "low stats"))
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

    for slot_type, slot in pairs(data) do
        local current_slot = self.slots[slot_type]
        if current_slot and slot.item_id then
            local id = slot.item_id

            if type(id) == "string" then
                id = id:match("%[(.-)%]") or id
                current_slot.item_id = hash(id)
            else
                current_slot.item_id = id
            end

            current_slot.amount = math.floor(slot.amount or 0)
            current_slot.uid = slot.uid
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

