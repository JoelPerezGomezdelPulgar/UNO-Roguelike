local dano = require("combate.damage")
local efectos_carta = require("cartas.effects")

local combate = {}

function combate.iniciar(state)
    state.turno_actual = 1
    state.aturdido = 0
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
    state.roboGratis = 0

    -- init hooks on relics
    for _, r in ipairs(state.reliquias or {}) do
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
    local game_mod = require("juego")
    game_mod.iniciar_metodos_entidades(state)

    -- Cooldown de poderes por combate (C)
    for _, p in ipairs(state.poderes or {}) do
        if p.cooldown_actual and p.cooldown_actual > 0 then
            local def = require("poderes.registry")[p.id]
            if def and def.cooldown and def.cooldown.type == "combates" then
                p.cooldown_actual = p.cooldown_actual - 1
            end
        end
    end
end

function combate.iniciar_turno(state, es_jugador)
    local entity = es_jugador and state.jugador or state.rival
    state.turn_entity = entity
    state.veloz_activo = 0
    state.aturdido = 0

    -- status effects on turn start
    for status_id, cargas in pairs(entity.status) do
        local def = require("estados.registry")[status_id]
        if def and def.on_turn_start then
            local nuevas = def.on_turn_start(state, cargas, entity)
            if nuevas ~= nil then
            if nuevas <= 0 then
                if def.on_end then def.on_end(state, cargas, entity) end
                entity.status[status_id] = nil
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
        for _, r in ipairs(state.reliquias or {}) do
            if r.on_turn_start then r.on_turn_start(state) end
        end
    end

    -- si está aturdido
    if state.aturdido and state.aturdido > 0 and es_jugador then
        return "aturdido"
    end
end

function combate.jugar_cartas(state, indices)
    if state.aturdido and state.aturdido > 0 then return { mensaje = "Estás aturdido" } end

    local jugador = state.jugador
    local cartas_a_jugar = {}
    for _, i in ipairs(indices) do
        if jugador.mano[i] then
            table.insert(cartas_a_jugar, jugador.mano[i])
        end
    end
    if #cartas_a_jugar == 0 then return { mensaje = "Sin cartas" } end
    if #cartas_a_jugar > 3 then return { mensaje = "Máximo 3 cartas" } end

    -- Verificar jugabilidad: probar orden original y luego permutaciones
    local top = state.mesa and state.mesa[#state.mesa]
    local function validar(orden)
        if not top then return true end
        local ant = top
        for _, c in ipairs(orden) do
            if not (c.valor == ant.valor or c.color == ant.color or (type(c.valor) == "number" and type(ant.valor) == "number" and c.valor == ant.valor + 1)) then
                return false
            end
            ant = c
        end
        return true
    end
    local function permutar(arr, n, usado, actual, resultados)
        if #actual == n then
            local copia = {}
            for _, idx in ipairs(actual) do table.insert(copia, arr[idx]) end
            table.insert(resultados, copia)
            return
        end
        for i = 1, n do
            if not usado[i] then
                usado[i] = true
                table.insert(actual, i)
                permutar(arr, n, usado, actual, resultados)
                table.remove(actual)
                usado[i] = false
            end
        end
    end
    if not validar(cartas_a_jugar) then
        local n = #cartas_a_jugar
        local resultados = {}
        permutar(cartas_a_jugar, n, {}, {}, resultados)
        local valido = false
        for _, orden in ipairs(resultados) do
            if validar(orden) then
                cartas_a_jugar = orden
                valido = true
                break
            end
        end
        if not valido then
            return { mensaje = "No se puede jugar esa combinación" }
        end
    end

    -- Procesar efectos antes de daño
    dano.procesar_cartas_jugadas(cartas_a_jugar, state)

    -- Calcular daño base por carta
    local suma_dano = dano.calcular_dano(cartas_a_jugar, state)
    state.danoBase = suma_dano

    -- Calcular multiplicador
    local mult_base = dano.calcular_multiplicador(cartas_a_jugar)
    local mult_final = dano.calcular_mult_final(state, cartas_a_jugar)
    local dano_total
    if mult_base == 2 and #cartas_a_jugar == 3 then
        local vals = {}
        for _, c in ipairs(cartas_a_jugar) do table.insert(vals, c.valor) end
        local par1, par2, solo
        if vals[1] == vals[2] then
            par1, par2, solo = 1, 2, 3
        elseif vals[2] == vals[3] then
            par1, par2, solo = 2, 3, 1
        else
            par1, par2, solo = 1, 3, 2
        end
        local dmg_par = dano.calcular_dano({cartas_a_jugar[par1], cartas_a_jugar[par2]}, state)
        local dmg_solo = dano.calcular_dano({cartas_a_jugar[solo]}, state)
        dano_total = math.floor(dmg_par * mult_base * mult_final + dmg_solo)
        state.danoMulti = mult_base
    else
        local mult = mult_base * mult_final
        state.danoMulti = mult
        dano_total = math.floor(suma_dano * mult)
    end

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

    -- Reliquias: on_play_card, on_escalera, etc.
    for _, r in ipairs(state.reliquias or {}) do
        if r.on_play_card then
            for _, c in ipairs(cartas_a_jugar) do
                local res = r.on_play_card(c, state)
                if res and res.oro then state.oro = (state.oro or 0) + res.oro end
            end
        end
        if r.on_escalera and dano.calcular_multiplicador(cartas_a_jugar) >= 3 then
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

    -- Aplicar estados a través de cartas (después de reliquias para que blasón elemental agregue "descompuesta" antes)
    dano.aplicar_estados(cartas_a_jugar, state)

    -- Seres: dioniso oro por escalera
    if state.dioniso_oro_escalera and dano.calcular_multiplicador(cartas_a_jugar) >= 3 then
        state.oro = (state.oro or 0) + state.dioniso_oro_escalera
    end
    if state.dioniso_comida_escalera and dano.calcular_multiplicador(cartas_a_jugar) >= 3 then
        state.comida = (state.comida or 0) + state.dioniso_comida_escalera
    end
    if state.hidra_penaliza_escalera and dano.calcular_multiplicador(cartas_a_jugar) >= 3 then
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
    for _, r in ipairs(state.reliquias or {}) do
        if r.id == "gema_caos" then
            local v = {}
            for _, c in ipairs(cartas_a_jugar) do table.insert(v, c.valor) end
            if #v == 3 and v[1] == v[2] and v[2] == v[3] then r.on_trio(state) end
        end
    end

    -- Sello de sangre
    for _, r in ipairs(state.reliquias or {}) do
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

function combate.robar_carta(state, es_jugador)
    local entity = es_jugador and state.jugador or state.rival
    local mazo = es_jugador and state.mazo_jugador or state.mazo_rival

    -- Reciclar mesa si mazo vacío (solo cartas del jugador)
    if #mazo == 0 and #state.mesa > 1 then
        local top = table.remove(state.mesa)
        local restantes = {}
        for _, c in ipairs(state.mesa) do
            if c.es_jugador then table.insert(mazo, c)
            else table.insert(restantes, c) end
        end
        state.mesa = { top }
        for _, c in ipairs(restantes) do table.insert(state.mesa, c) end
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
    for _, r in ipairs(state.reliquias or {}) do
        if r.id == "guantes_seda" then carta._bono_robo = 1 end
    end

    return carta
end

function combate.finalizar_turno(state)
    -- status effects on turn end
    for status_id, cargas in pairs(state.rival.status) do
        local def = require("estados.registry")[status_id]
        if def and def.on_turn_end then
            local nuevas = def.on_turn_end(state, cargas, state.rival)
            if nuevas ~= nil then
                if nuevas <= 0 then state.rival.status[status_id] = nil
                else state.rival.status[status_id] = nuevas end
            end
        end
    end
    for status_id, cargas in pairs(state.jugador.status) do
        local def = require("estados.registry")[status_id]
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
    state.absorcion_vida_activa = nil
    state.furia_activa = nil
    state.roboGratis = 0

    -- Cooldown de poderes por turno (T)
    for _, p in ipairs(state.poderes or {}) do
        if p.cooldown_actual and p.cooldown_actual > 0 then
            local def = require("poderes.registry")[p.id]
            if def and def.cooldown and def.cooldown.type == "turnos" then
                p.cooldown_actual = p.cooldown_actual - 1
            end
        end
    end
    combate.mano_vacia_ataque(state)
end

function combate.mano_vacia_ataque(state)
    if #state.jugador.mano > 0 then return nil end
    local suma_mazo = 0
    for _, c in ipairs(state.mazo_jugador) do
        suma_mazo = suma_mazo + (c.dano_base or c.valor)
    end
    local dano = suma_mazo * 10
    state.danoBase = suma_mazo
    state.danoMulti = 10
    state.rival.vida = state.rival.vida - dano
    local cargas_aturdido = 2
    for _, r in ipairs(state.reliquias or {}) do
        if r.on_aturdimiento then
            local red = r.on_aturdimiento(state)
            if red then cargas_aturdido = cargas_aturdido + red end
        end
    end
    if cargas_aturdido > 0 then
        state.jugador:aplicar_estados("aturdido", cargas_aturdido)
        state.aturdido = cargas_aturdido
    end

    -- Barajar mazo, mantener la última carta jugada en mesa (solo cartas del jugador)
    local ultima_carta = table.remove(state.mesa)
    local pool = {}
    for _, c in ipairs(state.mesa or {}) do
        if c.es_jugador then table.insert(pool, c) end
    end
    for _, c in ipairs(state.mazo_jugador or {}) do table.insert(pool, c) end
    state.mesa = {}
    state.mazo_jugador = {}
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for i = 1, 7 do
        if #pool > 0 then
            table.insert(state.jugador.mano, table.remove(pool))
        end
    end
    table.insert(state.mesa, ultima_carta)
    state.mazo_jugador = pool

    return { dano = dano, mensaje = "Ataque final! " .. dano .. " daño pero aturdido 2 turnos" }
end

return combate
