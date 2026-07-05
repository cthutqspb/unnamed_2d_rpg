local game_state = require("main.modules.game_state.game_state")
local units_state = require("main.modules.game_state.units_state")
local units_db = require("main.modules.data.units_db")
local factions_db = require("main.modules.data.factions_db")

local M = {}

-- 📐 ВЕСОВОЙ КОЭФФИЦИЕНТ КАНOНА WOW (В пикселях Meadows-карты):
-- За каждый уровень разницы между мобом и целью, базовый радиус агро 
-- будет динамически расширяться или сжиматься на эту величину!
local PIXELS_PER_LEVEL = 15

-- Абсолютный фоллбек, если в units_db вдруг забыли прописать радиус
local DEFAULT_BASE_RADIUS = 200

---Слепой ААА-сканер агрессии с динамическим левел-скалированием (WoW-канон).
---Вызывается в центральном update мира (например, раз в 5 кадров для оптимизации CPU).
function M.update_threat_perception()
    -- Внутри perception_manager.lua в методе M.update_threat_perception():

    if not units_state or not units_state.registry then return end

    -- Пробегаемся по ВСЕМ живым существам в RAM-реестре вселенной!
    for caster_uid, caster_unit in pairs(units_state.registry) do
        -- 🚀 Си-гвард базовой жизни: сканируем только живых не-игроков с ИИ-контуром
        if not caster_unit.is_player and not caster_unit.combat.is_dead then
            -- =========================================================================
            -- 🤬 ПОЛИМОРФНЫЙ АAА-ДЕТЕКТОР МЕСТИ НЕЙТРАЛОВ (ВЫНЕСЕНО НА САМЫЙ ВВЕРХ):
            -- =========================================================================
            -- Этот блок теперь стоит ДО гварда combat_target_uid!
            -- Нам наглухо насрать, какого уровня дракон (1 или 25) и сидит ли у него 
            -- в памяти какой-то старый таргет! Если боёвка всадила ему last_attacker_uid 
            -- в SSOT-реестр — Мозг ВЫШЕ И ТРEБOВAТEЛЬНO взводит агро на обидчика,
            -- очищает флаг и шёлково уходит на следующую итерацию через else!
            if caster_unit.combat.last_attacker_uid and caster_unit.combat.last_attacker_uid ~= "" then
                local current_attacker = caster_unit.combat.last_attacker_uid

                caster_unit.combat.last_attacker_uid = nil -- Закрыли транзакцию
                game_state.set_unit_aggro_target(caster_uid, current_attacker)

                print(string.format("🤬 МЕСТЬ [Perception]: Высокоуровневый нейтрал [%s] (Lvl %d) получил урон! Мозг перехватил агро на обидчика [%s]!",
                    caster_uid, caster_unit.level or 1, current_attacker))

            else
                -- =========================================================================
                -- 🟢 ПАССИВНЫЙ ФРАКЦИОННЫЙ ПОИСК ЦЕЛЕЙ ПО РАДИУСУ ДЛЯ МИРНЫХ МОБОВ:
                -- =========================================================================
                -- Сюда мы падаем, только если моба никто физически не бил!
                -- И вот именно здесь встаёт твой законный гвард отсутствия боевой цели!
                if not caster_unit.combat.combat_target_uid or caster_unit.combat.combat_target_uid == "" then
                    local source_unit_position = caster_unit.saved_position
                    local source_unit_faction = caster_unit.identity.faction or "undead"
                    local source_unit_level = caster_unit.level or 1

                    if source_unit_position then
                        local db_cfg = units_db.get_unit(caster_unit.unit_id)
                        local base_radius = db_cfg and db_cfg.ai.base_aggro_radius or DEFAULT_BASE_RADIUS

                        -- Ищем потенциальных врагов среди ВСЕХ остальных существ в реестре RAM!
                        for target_unit_uid, target_unit in pairs(units_state.registry) do
                            if target_unit_uid ~= caster_uid and not target_unit.combat.is_dead then
                                local target_unit_faction = target_unit.identity.faction or "neutral_humanoid"

                                -- ААА-ФИЛЬТР ФРАКЦИЙ:
                                if factions_db.is_hostile(source_unit_faction, target_unit_faction) then
                                    local target_unit_position = target_unit.saved_position

                                    if target_unit_position then
                                        local distance = vmath.length(target_unit_position - source_unit_position)
                                        local target_unit_level = target_unit.level or 1

                                        -- LEVEL-BASED AGGRO RADIUS FORMULA:
                                        local level_diff = source_unit_level - target_unit_level
                                        local dynamic_aggro_radius = base_radius + (level_diff * PIXELS_PER_LEVEL)

                                        if dynamic_aggro_radius < 50 then dynamic_aggro_radius = 50 end

                                        -- ЦЕЛЬ ОБНАРУЖЕНА И ВЗВЕДЕНА В ПРИЦЕЛ:
                                        if distance <= dynamic_aggro_radius then
                                            game_state.set_unit_aggro_target(caster_uid, target_unit_uid)
                                            print(string.format(
                                              "👿 ПЕРЦЕПЦИЯ: Моб [%s] заагрил врага [%s]! Радиус: %d пкс",
                                                    caster_uid, target_unit_uid, dynamic_aggro_radius
                                                )
                                            )
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end -- Конец гварда combat_target_uid == ""
            end -- Конец ветки else детектора мести
        end -- Конец гварда базовой жизни не-игрока
    end -- Конец цикла pairs
end

return M

