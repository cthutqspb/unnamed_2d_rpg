local player_inventory = require("main.modules.player.player_inventory")

local M = {}

---@class InventoryModel
---@field items table Таблица предметов
---@field max_slots number Лимит слотов
---@field get_item fun(self:InventoryModel, idx:number):table
---@field set_item fun(self:InventoryModel, idx:number, data:table|nil)
---@field swap_slots fun(self:InventoryModel, from:number, to:number)
---@field try_stack_items fun(self:InventoryModel, from:number, to:number, cfg:table):boolean
---@field try_stack_items_from fun(self:InventoryModel, other:InventoryModel, from:number, to:number, cfg:table):boolean
---@field split_stack fun(self:InventoryModel, other:InventoryModel, from:number, to:number, amt:number, cfg:table):boolean

-- Функция создания обертки для сундуков/контейнеров
function M.wrap(container_state)
    local instance = {
        items = container_state.items,
        max_slots = container_state.max_slots or 0
    }

    -- 1. БАЗОВЫЕ МЕТОДЫ (Прокси к player_inventory)
    -- Мы просто копируем ссылки на функции, двоеточие само подставит нужный self
    instance.get_item = player_inventory.get_item
    instance.set_item = player_inventory.set_item
    instance.swap_slots = player_inventory.swap_slots
    instance.get_first_empty_slot = player_inventory.get_first_empty_slot
    
    -- 2. СЛОЖНАЯ ЛОГИКА (Стаканье и Сплит)
    -- Эти методы в player_inventory теперь работают через self.items
    instance.try_stack_items = player_inventory.try_stack_items
    instance.try_stack_items_from = player_inventory.try_stack_items_from
    instance.try_stack_item_anywhere = player_inventory.try_stack_item_anywhere
    instance.split_stack = player_inventory.split_stack
    
    ---@cast instance InventoryModel
    return instance
end

return M

