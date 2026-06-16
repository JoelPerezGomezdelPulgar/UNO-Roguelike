local damage = require("combat.damage")
local card_effects = require("cards.effects")

local combat = {}

function combat.init(state)
    state.turno_actual = 1
    state.aturdido = false
    state.veloz_activo = 0
    state.golpe_decisivo = nil
    state.furia_activa = nil
    state.absorcion_vida_activa = nil
    state.elusion_activa = nil
    state.reduccion_dano = 0
    state.numero_marcado = nil
    state.ojo_ra_mult = 0
    state.blason_contador = 0
    state.carta_marcada_activa = false
    state.danoBase = 0
    state.danoMulti = 1
    state.jugador.vida = state.jugador.vida_max

    -- init hooks on relics
    for _, r in ipairs(state.relics or {}) do
        if r.on_init_combat then r.on_init_combat(state) end
        if r.on_combat_start then r.on_combat_start(state) end
    end

    -- Reunir todas las cartas del jugador y barajar
    local pool = {}
    for _, c in ipairs(state.jugador.mano or {}) do table.insert(pool, c) end
    state.jugador.mano = {}
    for _, c in ipairs(state.mesa or {}) do table.insert(pool, c) end
    state.mesa = {}
    for _, c in ipairs(state.mazo_jugador or {}) do table.insert(pool, c) end
    state.mazo_jugador = {}
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    -- Robar 8 cartas (7 mano + 1 mesa)
    for i = 1, 8 do
        if #pool > 0 then
            table.insert(state.jugador.mano, table.remove(pool))
        end
    end

    -- Poner 1 carta en mesa desde la mano
    if #state.jugador.mano > 0 then
        table.insert(state.mesa, table.remove(state.jugador.mano))
    end

    -- El resto va al mazo
    state.mazo_jugador = pool

    -- Re-attach entity methods (rival may be new after avanzar_nivel)
    local game_mod = require("game")
    game_mod.init_entity_methods(state)
end

function combat.start_turn(state, es_jugador)
    local entity = es_jugador and state.jugador or state.rival
    state.turn_entity = entity
    state.veloz_activo = 0

    -- status effects on turn start
    for status_id, cargas in pairs(entity.status) do
        local def = require("status.registry")[status_id]
        if def and def.on_turn_start then
            local nuevas = def.on_turn_start(state, cargas, entity)
            if nuevas ~= nil then
                if nuevas <= 0 then entity.status[status_id] = nil
                else entity.status[status_id] = nuevas end
            end
        end
    end

    -- dano por turno (Zeus, Dioniso)
    if es_jugador and state.dano_por_turno then
        state.jugador.vida = state.jugador.vida - state.dano_por_turno
    end

    -- antídoto débil
    if es_jugador then
        for _, r in ipairs(state.relics or {}) do
            if r.on_turn_start then r.on_turn_start(state) end
        end
    end

    -- si está aturdido
    if state.aturdido and es_jugador then
        return "aturdido"
    end
end

function combat.jugar_cartas(state, indices)
    if state.aturdido then return { mensaje = "Estás aturdido" } end

    local jugador = state.jugador
    local cartas_a_jugar = {}
    for _, i in ipairs(indices) do
        if jugador.mano[i] then
            table.insert(cartas_a_jugar, jugador.mano[i])
        end
    end
    if #cartas_a_jugar == 0 then return { mensaje = "Sin cartas" } end
    if #cartas_a_jugar > 3 then return { mensaje = "Máximo 3 cartas" } end

    -- Verificar jugabilidad secuencial
    local top = state.mesa and state.mesa[#state.mesa]
    for _, c in ipairs(cartas_a_jugar) do
        if top and not (c.valor == top.valor or c.color == top.color or (type(c.valor) == "number" and type(top.valor) == "number" and c.valor == top.valor + 1)) then
            return { mensaje = "No se puede jugar " .. tostring(c) .. " sobre " .. tostring(top) }
        end
        top = c
    end

    -- Procesar efectos antes de daño
    damage.procesar_cartas_jugadas(cartas_a_jugar, state)

    -- Calcular daño base por carta
    local suma_dano = damage.calcular_dano(cartas_a_jugar, state)
    state.danoBase = suma_dano

    -- Primer carta: golpe decisivo
    if state.golpe_decisivo then
        suma_dano = suma_dano + state.golpe_decisivo
        state.golpe_decisivo = nil
    end
    if state.aquiles_primera and cartas_a_jugar[1] then
        suma_dano = suma_dano + state.aquiles_primera
    end

    -- Calcular multiplicador
    local mult = damage.calcular_multiplicador(cartas_a_jugar)
    mult = mult * damage.calcular_mult_final(state, cartas_a_jugar)
    state.danoMulti = mult

    local dano_total = math.floor(suma_dano * mult)

    -- Aplicar penalización daño recibido (seres)
    if state.dano_pct then dano_total = math.floor(dano_total * state.dano_pct) end

    -- Aplicar daño al rival
    state.rival.vida = state.rival.vida - dano_total

    -- Absorción de vida
    if state.absorcion_vida_activa and state.absorcion_vida_activa > 0 then
        state.jugador.vida = math.min(state.jugador.vida_max, state.jugador.vida + math.floor(dano_total * 0.5))
    end

    -- Marcar cartas como jugadas (para Hades recycle)
    for _, c in ipairs(cartas_a_jugar) do
        c._jugada = true
    end

    -- Remover cartas de la mano
    table.sort(indices, function(a,b) return a > b end)
    local cartas_removidas = {}
    for _, i in ipairs(indices) do
        table.insert(cartas_removidas, table.remove(jugador.mano, i))
    end

    -- Añadir a mesa
    for _, c in ipairs(cartas_removidas) do
        table.insert(state.mesa, c)
    end

    -- Aplicar estados a través de cartas
    damage.aplicar_estados(cartas_a_jugar, state)

    -- Reliquias: on_play_card, on_escalera, etc.
    for _, r in ipairs(state.relics or {}) do
        if r.on_play_card then
            for _, c in ipairs(cartas_a_jugar) do
                local res = r.on_play_card(c, state)
                if res and res.oro then state.oro = (state.oro or 0) + res.oro end
            end
        end
        if r.on_escalera and damage.calcular_multiplicador(cartas_a_jugar) >= 3 then
            local res = r.on_escalera(state)
            if res then state.comida = (state.comida or 0) + res end
        end
        if r.on_trio then
            local v = {}
            for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor) end
            if #v == 3 and v[1] == v[2] and v[2] == v[3] then r.on_trio(state) end
        end
        if r.on_escalera_color then
            local v, cols = {}, {}
            for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor); table.insert(cols, c.color) end
            if #v == 3 and cols[1] == cols[2] and cols[2] == cols[3] and v[1]+1 == v[2] and v[2]+1 == v[3] then
                r.on_escalera_color(state)
            end
        end
    end

    -- Seres: dioniso oro por escalera
    if state.dioniso_oro_escalera and damage.calcular_multiplicador(cartas_a_jugar) >= 3 then
        state.oro = (state.oro or 0) + state.dioniso_oro_escalera
    end
    if state.dioniso_comida_escalera and damage.calcular_multiplicador(cartas_a_jugar) >= 3 then
        state.comida = (state.comida or 0) + state.dioniso_comida_escalera
    end
    if state.hidra_penaliza_escalera and damage.calcular_multiplicador(cartas_a_jugar) >= 3 then
        state.oro = math.max(0, (state.oro or 0) - state.hidra_penaliza_escalera)
    end
    if state.hidra_dano_amarillo then
        for _, c in ipairs(cartas_a_jugar) do
            if c.color == "Amarillo" then state.jugador.vida = state.jugador.vida - state.hidra_dano_amarillo end
        end
    end

    -- Veloz
    if state.veloz_activo > 0 then
        local extra = state.veloz_activo
        state.veloz_activo = 0
        -- aplicar a la siguiente carta (si hubiera más)
    end

    -- Blasón elemental: contar cartas
    if state.blason_contador then
        state.blason_contador = state.blason_contador + #cartas_a_jugar
    end

    -- Hefesto: mejora carta
    if state.hefesto_mejora then
        if math.random() < state.hefesto_mejora.pct then
            local mejora_idx = math.random(#state.jugador.mano)
            if state.jugador.mano[mejora_idx] then
                state.jugador.mano[mejora_idx].dano_base = (state.jugador.mano[mejora_idx].dano_base or state.jugador.mano[mejora_idx].valor) + state.hefesto_mejora.valor
            end
        end
    end
    if state.hefesto_destruye and math.random() < state.hefesto_destruye then
        if #state.jugador.mano > 0 then
            table.remove(state.jugador.mano, math.random(#state.jugador.mano))
        end
    end

    -- Hidra: regenera por trío
    if state.hidra_regenera_trio then
        local v = {}
        for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor) end
        if #v == 3 and v[1] == v[2] and v[2] == v[3] then
            state.jugador.vida = math.min(state.jugador.vida_max, state.jugador.vida + state.hidra_regenera_trio)
        end
    end
    if state.hidra_dano_rival then
        local v = {}
        for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor) end
        if #v == 3 and v[1] == v[2] and v[2] == v[3] then
            state.rival.vida = state.rival.vida - state.hidra_dano_rival
        end
    end

    -- Gema del caos: trío aplica efecto
    for _, r in ipairs(state.relics or {}) do
        if r.id == "gema_caos" then
            local v = {}
            for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor) end
            if #v == 3 and v[1] == v[2] and v[2] == v[3] then r.on_trio(state) end
        end
    end

    -- Sello de sangre
    for _, r in ipairs(state.relics or {}) do
        if r.id == "sello_sangre" then
            state.jugador.vida = math.min(state.jugador.vida_max, state.jugador.vida + #cartas_a_jugar)
        end
    end

    return {
        dano = dano_total,
        mult = mult,
        cartas = cartas_a_jugar,
        mensaje = "Jugaste " .. #cartas_a_jugar .. " cartas por " .. dano_total .. " de daño",
    }
end

function combat.robar_carta(state, es_jugador)
    local entity = es_jugador and state.jugador or state.rival
    local mazo = es_jugador and state.mazo_jugador or state.mazo_rival

    -- Reciclar mesa si mazo vacío
    if #mazo == 0 and #state.mesa > 1 then
        local top = table.remove(state.mesa)
        for _, c in ipairs(state.mesa) do table.insert(mazo, c) end
        state.mesa = { top }
        for i = #mazo, 2, -1 do
            local j = math.random(i)
            mazo[i], mazo[j] = mazo[j], mazo[i]
        end
    end

    if #mazo == 0 then return nil end

    local carta = table.remove(mazo)
    carta.es_robada = true
    table.insert(entity.mano, carta)

    -- Guantes de seda
    for _, r in ipairs(state.relics or {}) do
        if r.id == "guantes_seda" then carta._bono_robo = 1 end
    end

    return carta
end

function combat.end_turn(state)
    -- status effects on turn end
    for status_id, cargas in pairs(state.rival.status) do
        local def = require("status.registry")[status_id]
        if def and def.on_turn_end then
            local nuevas = def.on_turn_end(state, cargas, state.rival)
            if nuevas ~= nil then
                if nuevas <= 0 then state.rival.status[status_id] = nil
                else state.rival.status[status_id] = nuevas end
            end
        end
    end
    for status_id, cargas in pairs(state.jugador.status) do
        local def = require("status.registry")[status_id]
        if def and def.on_turn_end then
            local nuevas = def.on_turn_end(state, cargas, state.jugador)
            if nuevas ~= nil then
                if nuevas <= 0 then state.jugador.status[status_id] = nil
                else state.jugador.status[status_id] = nuevas end
            end
        end
    end

    -- Aquiles: número maldito
    if state.aquiles_numero_maldito then
        local num = math.random(0, 9)
        for _, c in ipairs(state.jugador.mano) do
            if c.valor == num then
                state.jugador.vida = state.jugador.vida - state.aquiles_numero_maldito.dano
                break
            end
        end
    end

    state.turno_actual = state.turno_actual + 1
    state.danoBase = 0
    state.danoMulti = 1
end

function combat.mano_vacia_ataque(state)
    if #state.jugador.mano > 0 or #state.mazo_jugador == 0 then return nil end
    local suma_mazo = 0
    for _, c in ipairs(state.mazo_jugador) do
        suma_mazo = suma_mazo + (c.dano_base or c.valor)
    end
    local dano = suma_mazo * 10
    state.danoBase = suma_mazo
    state.danoMulti = 10
    state.rival.vida = state.rival.vida - dano
    state.aturdido = true
    -- Anillo del vacío reduce aturdimiento
    for _, r in ipairs(state.relics or {}) do
        if r.on_aturdimiento then
            local red = r.on_aturdimiento(state)
            if red then -- keep aturdido for 1 turno instead of 2
            end
        end
    end
    return { dano = dano, mensaje = "Ataque final! " .. dano .. " daño pero aturdido 2 turnos" }
end

return combat
