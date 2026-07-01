local game_state = require("main.modules.game_state.game_state")
local units_state = require("main.modules.game_state.units_state")
local units_db = require("main.modules.data.units_db")
local factions_db = require("main.modules.data.factions_db")

local M = {}

-- 📐 ВЕСОВОЙ КОЭФФИЦИЕНТ КАНOНА WOW (В пикселях Meadows-карты):
-- За каждый уровень разницы между мобом и целью, базовый радиус агро 
-- будет динамически расширяться или сжиматься на эту величину!
local PIXELS_PER_LEVEL = 25

-- Абсолютный фоллбек, если в units_db вдруг забыли прописать радиус
local DEFAULT_BASE_RADIUS = 200

---Слепой ААА-сканер агрессии с динамическим левел-скалированием (WoW-канон).
---Вызывается в центральном update мира (например, раз в 5 кадров для оптимизации CPU).
function M.update_threat_perception()
    if not units_state or not units_state.registry then return end

    -- Пробегаемся по ВСЕМ живым существам в RAM-реестре вселенной!
    for caster_uid, caster_unit in pairs(units_state.registry) do
        -- Сканируем только тех, у кого есть ИИ-контур, кто жив, не игрок и сейчас БЕЗ ТАРГЕТА!
        if not caster_unit.is_player and not caster_unit.is_dead and (not caster_unit.combat_target_uid or caster_unit.combat_target_uid == "") then
            local source_unit_position = caster_unit.saved_position
            local source_unit_faction = caster_unit.faction or "undead"
            local source_unit_level = caster_unit.level or 1

            if source_unit_position then
                -- 🛡️ ВЫТАCКИВАЕМ БАЗУ ИЗ DB-КОНФИГА МОНСТРА:
                local db_cfg = units_db.get_unit(caster_unit.unit_id)
                local base_radius = db_cfg and db_cfg.base_aggro_radius or DEFAULT_BASE_RADIUS

                -- Ищем потенциальных врагов среди ВСЕХ остальных существ в реестре RAM!
                for target_unit_uid, target_unit in pairs(units_state.registry) do
                    if target_unit_uid ~= caster_uid and not target_unit.is_dead then
                        -- 🦾 АБСОЛЮТНЫЙ ПОЛИМОРФИЗМ ФРАКЦИЙ:
                        -- Больше никаких хардкодных "alliance" и "monster" фоллбеков!
                        -- Берем чистую, легальную строку фракции ("neutral_humanoid", "undead", "green_dragon") 
                        -- напрямую из RAM-паспорта Души жертвы, выданной сейв-менеджером или units_db!
                        local target_unit_faction = target_unit.faction or "neutral_humanoid"

                        -- 🦾 1. ААА-ФИЛЬТР ФРАКЦИЙ (СИНХРОНИЗИРОВАНО С FACTIONS_DB):
                        -- Передаем выровненные, зрячие переменные строго по контракту сигнатуры!
                        if factions_db.is_hostile(source_unit_faction, target_unit_faction) then
                            local target_unit_position = target_unit.saved_position

                            if target_unit_position then
                                local distance = vmath.length(target_unit_position - source_unit_position)
                                local target_unit_level = target_unit.level or 1

                                -- =========================================================================
                                -- 📐 2. LEVEL-BASED AGGRO RADIUS FORMULA (WoW-Канон):
                                -- =========================================================================
                                -- Считаем разницу в уровнях. 
                                -- Если моб старше жертвы — разница положительная (радиус РАСШИРЯЕТСЯ).
                                -- Если жертва старше моба — разница отрицательная (моб СЛЕПНЕТ).
                                local level_diff = source_unit_level - target_unit_level
                                local dynamic_aggro_radius = base_radius + (level_diff * PIXELS_PER_LEVEL)

                                -- Жесткий Си-гвард нижней границы, чтобы радиус не ушел в ноль или минус
                                if dynamic_aggro_radius < 50 then
                                    dynamic_aggro_radius = 50
                                end
                                -- =========================================================================

                                -- 🎯 ЦЕЛЬ ОБНАРУЖЕНА И ВЗВЕДЕНА В ПРИЦЕЛ:
                                if distance <= dynamic_aggro_radius then
                                    game_state.set_unit_aggro_target(caster_uid, target_unit_uid)
                                    print(string.format(
                                      "👿 ПЕРЦЕПЦИЯ: Моб [%s] (Фракция: %s, Lvl %d) заагрил врага [%s] (Фракция: %s, Lvl %d)! Радиус: %d пкс (База: %d)",
                                            caster_uid,
                                            source_unit_faction,
                                            source_unit_level,
                                            target_unit_uid,
                                            target_unit_faction,
                                            target_unit_level,
                                            dynamic_aggro_radius,
                                            base_radius
                                        )
                                    )
                                    break -- Цель зафиксирована, прекращаем перебор для этого моба в этом тике
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

return M

