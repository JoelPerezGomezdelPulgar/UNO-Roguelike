local combate = require("combate.init")
local mundo = require("mundo")

local juego = {}

function juego.nuevo_juego()
    local state = {
        -- Jugador
        jugador = {
            id = 1,
            nombre = "Alice",
            vida = 100,
            vida_max = 100,
            mano = {},
            status = {},
            mano_congelada = {},
        },
        -- Mazo principal
        mazo_jugador = {},
        -- Recursos
        oro = 10,
        comida = 0,
        -- Colecciones
        reliquias = {},
        poderes = {},
        objetos = {},
        seres = {},
        -- Panel de reliquias
        reliquias_offset = 0,
        reliquias_hueco_w = 100,
        reliquias_panel_x = 20,
        reliquias_panel_y = 265,
        reliquias_panel_w = 430,
        arrastrando_reliquia = nil,
        arrastrar_inicio_x = nil,
        -- Flags
        lagrimas_usadas = 0,
        fase = "menu",
        turno_actual = 1,
        aturdido = 0,
        veloz_activo = 0,
    }
    return state
end

function juego.iniciar_partida(state)
    local card_defs = require("datos.cards")
    local mazo = {}
    for _, c in pairs(card_defs) do
        table.insert(mazo, { id = c.id, valor = c.valor, color = c.color, dano_base = c.dano_base, es_jugador = true })
    end
    -- Shuffle
    for i = #mazo, 2, -1 do
        local j = math.random(i)
        mazo[i], mazo[j] = mazo[j], mazo[i]
    end
    state.mazo_jugador = mazo

    state.jugador.vida = 100
    state.jugador.vida_max = 100
    state.oro = 10
    state.reliquias = {}
    state.poderes = {}
    state.objetos = {}
    state.seres = {}

    mundo.nuevo_mundo(state)
    combate.iniciar(state)
    state.fase = "combat"
end

function juego.turno_jugador(state, accion, datos)
    if state.fase ~= "combat" then return nil end

    local inicio = combate.iniciar_turno(state, true)
    if inicio == "aturdido" then
        if accion == "saltar" then
            combate.finalizar_turno(state)
            juego.turno_ia(state)
            return { mensaje = "Turno saltado (aturdido)" }
        elseif accion == "robar" then
        combate.robar_carta(state, true)
        end
        return { mensaje = "Estás aturdido" }
    end

    if accion == "jugar" then
        local resultado = combate.jugar_cartas(state, datos.indices)
        if resultado and resultado.dano then
            combate.finalizar_turno(state)
            -- check rival death
            if state.rival.vida <= 0 then
                mundo.procesar_victoria(state)
                state.fase = "tienda"
                return { type = "victoria", mensaje = "Victoria!" }
            end
            -- turno de IA
            juego.turno_ia(state)
            return resultado
        end
        return resultado
    elseif accion == "robar" then
        combate.robar_carta(state, true)
        if state.roboGratis and state.roboGratis > 0 then
            state.roboGratis = state.roboGratis - 1
        else
            state.jugador.turno_ultimo = "robo"
            combate.finalizar_turno(state)
            juego.turno_ia(state)
        end
        return { mensaje = "Robaste una carta" }
    elseif accion == "usar_poder" then
        return juego.usar_poder(state, datos.poder_idx, datos.target)
    elseif accion == "usar_objeto" then
        return juego.usar_objeto(state, datos.objeto_idx, datos.target)
    end
end

function juego.turno_ia(state)
    -- Simple AI: buscar mejor jugada
    if state.rival.vida <= 0 then return end

    local mejor, mejor_dano = nil, 0
    -- Combinaciones de 1-3 cartas
    local function combos(arr, k)
        local r, rc = {}, {}
        local function rec(s)
            if #rc == k then table.insert(r, {table.unpack(rc)}); return end
            for i = s, #arr do table.insert(rc, arr[i]); rec(i+1); table.remove(rc) end
        end
        rec(1); return r
    end

    local indices = {}
    for i = 1, #state.rival.mano do indices[i] = i end

    for r = 1, math.min(3, #state.rival.mano) do
        local c = combos(indices, r)
        for _, combo in ipairs(c) do
            local cartas = {}
            for _, i in ipairs(combo) do table.insert(cartas, state.rival.mano[i]) end
            local top = state.mesa[#state.mesa]
            local ok = true
            for i, carta in ipairs(cartas) do
                if top then
                    if i == 1 then
                        if not (carta.valor == top.valor or carta.color == top.color) then
                            ok = false; break
                        end
                    else
                        if not (carta.valor == top.valor or carta.color == top.color or
                           (type(carta.valor) == "number" and type(top.valor) == "number" and carta.valor == top.valor + 1)) then
                            ok = false; break
                        end
                    end
                end
                top = carta
            end
            if ok then
                local s = 0
                for _, c in ipairs(cartas) do s = s + (c.dano_base or c.valor) end
                if s > mejor_dano then mejor_dano = s; mejor = combo end
            end
        end
    end

    if mejor then
        local cartas = {}
        for _, i in ipairs(mejor) do table.insert(cartas, state.rival.mano[i]) end
        -- Remover cartas
        table.sort(mejor, function(a,b) return a > b end)
        for _, i in ipairs(mejor) do table.remove(state.rival.mano, i) end
        for _, c in ipairs(cartas) do table.insert(state.mesa, c) end

        local dano = 0
        for _, c in ipairs(cartas) do dano = dano + (c.dano_base or c.valor) end
        state.danoBase = dano
        state.danoMulti = 1
        -- Reducción de daño
        dano = math.max(0, dano - state.reduccion_dano)
        -- Escudo de éter
        for _, r in ipairs(state.reliquias or {}) do
            if r.on_enemy_card_damage then dano = dano + r.on_enemy_card_damage(cartas[1], state) end
        end

        -- Elusión: reflejar daño
        if state.elusion_activa then
            state.rival.vida = state.rival.vida - dano
            dano = 0
            state.elusion_activa = nil
        end

        -- Espejo reflector: si todas las cartas son del mismo color
        if #cartas > 0 then
            local mismo_color = true
            local color_ref = cartas[1].color
            for _, c in ipairs(cartas) do
                if c.color ~= color_ref then
                    mismo_color = false
                    break
                end
            end
            if mismo_color then
                for _, r in ipairs(state.reliquias or {}) do
                    if r.on_rival_color_hand then
                        r.on_rival_color_hand(state, dano)
                    end
                end
            end
        end

        state.jugador.vida = state.jugador.vida - dano
    else
        combate.robar_carta(state, false)
    end
end

function juego.usar_poder(state, idx, target)
    if not state.poderes[idx] then return { mensaje = "Poder no encontrado" } end
    local poder = state.poderes[idx]
    local def = require("poderes.registry")[poder.id]
    if not def then return { mensaje = "Poder desconocido" } end

    -- Check cooldown
    if poder.cooldown_actual and poder.cooldown_actual > 0 then
        return { mensaje = "Poder en recarga: " .. poder.cooldown_actual }
    end

    local resultado = def.activar(state, target)
    -- Set cooldown
    poder.cooldown_actual = def.cooldown.max
    return resultado
end

function juego.usar_objeto(state, idx, target)
    if not state.objetos[idx] then return { mensaje = "Objeto no encontrado" } end
    local obj = state.objetos[idx]
    local def = require("objetos.registry")[obj.id]
    if not def then return { mensaje = "Objeto desconocido" } end

    state.objetos_objetivo = target
    local resultado = def.usar(state)
    table.remove(state.objetos, idx)
    return resultado
end

function juego.comprar_tienda(state, idx)
    local tienda = require("tienda")
    return tienda.comprar(state, idx)
end

function juego.reroll_tienda(state)
    local tienda = require("tienda")
    return tienda.reroll(state)
end

-- Helper methods on jugador/rival
local metodos_entidades = {}
function metodos_entidades:tiene_estados(id)
    return self.status and self.status[id] and self.status[id] > 0
end
function metodos_entidades:aplicar_estados(id, cargas)
    self.status = self.status or {}
    local def = require("estados.registry")[id]
    if def and def.on_aplicar then
        cargas = def.on_aplicar(self, cargas, self) or cargas
    end
    if cargas > 0 then
        local max = def and def.max_cargas
        self.status[id] = max and math.min(max, (self.status[id] or 0) + cargas) or (self.status[id] or 0) + cargas
    end
end
function metodos_entidades:eliminar_estados(id)
    if self.status then
        local def = require("estados.registry")[id]
        if def and def.on_remove then def.on_remove(self) end
        self.status[id] = nil
    end
end

function juego.repetir_carta(state, carta)
    if carta.efectos then
        dano = require("combate.damage")
        for _, ef in ipairs(carta.efectos) do
            local ef_def = require("cartas.effects")[ef]
            if ef_def and ef_def.aplicar then
                ef_def.aplicar(carta, state)
            end
            if ef_def and ef_def.on_play then
                ef_def.on_play(carta, state)
            end
        end
    end
    local dmg = carta.dano_base or carta.valor
    for _, r in ipairs(state.reliquias or {}) do
        if r.on_card_damage then dmg = dmg + r.on_card_damage(carta, state) end
    end
    if state.numero_marcado and carta.valor == state.numero_marcado then dmg = dmg + 3 end
    return dmg
end

-- Attach methods to entities
function juego.iniciar_metodos_entidades(state)
    setmetatable(state.jugador, { __index = metodos_entidades })
    if state.rival then
        setmetatable(state.rival, { __index = metodos_entidades })
    end
end

return juego
