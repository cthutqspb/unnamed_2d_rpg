local M = {}

-- Основная функция проверки
-- Возвращает: is_ok (bool), errors (table: {stat_id = true})
function M.check(item_cfg, player)
    local results = {
        is_ok = true,
        errors = {}
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
        elseif req_id == "resource" then
            -- Проверяем, есть ли у игрока нужный ресурс (например, мана)
            if req_val == "mana" then
                stat_ok = (player.max_mana and player.max_mana > 0)
            end
        else
            -- Проверка статов (strength, agility и т.д.)
            -- Используем current_stats, чтобы учитывать бонусы от шмота
            player_val = player.current_stats[req_id] or 0
            stat_ok = (player_val >= req_val)
        end

        if not stat_ok then
            results.is_ok = false
            results.errors[req_id] = true
        end
    end

    return results
end

return M



