---@class RequirementResult
---@field is_ok boolean
---@field errors table<string, boolean>
---@field reason string|nil

local M = {}

-- Основная функция проверки
---@param item_cfg table
---@param player table
---@param _item Item @Префикс подчеркивания убирает ошибку "unused"
---@return RequirementResult
function M.check(item_cfg, player, _item)
    ---@type RequirementResult
    local results = {
        is_ok = true,
        errors = {},
        reason = nil -- Явно добавляем поле, чтобы соответствовать классу
    }

    if not item_cfg.required then
        return results
    end

    for req_id, req_val in pairs(item_cfg.required) do
        local player_val = 0
        local stat_ok = true

        if req_id == "level" then
            player_val = player.level
            stat_ok = (player_val >= req_val)
            if not stat_ok then results.reason = "low_level" end
        elseif req_id == "resource" then
            if req_val == "mana" then
                stat_ok = (player.max_mana and player.max_mana > 0)
                if not stat_ok then results.reason = "no_mana_resource" end
            end
        else
            player_val = player.current_stats[req_id] or 0
            stat_ok = (player_val >= req_val)
            if not stat_ok then results.reason = "low_stats" end
        end

        if not stat_ok then
            results.is_ok = false
            results.errors[req_id] = true
        end
    end

    return results
end

return M

