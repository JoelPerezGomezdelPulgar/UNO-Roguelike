local combat = require("combat.init")
local world = require("world")

local game = {}

function game.nuevo_juego()
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
        -- Flags
        lagrimas_usadas = 0,
        fase = "menu",
        turno_actual = 1,
        aturdido = false,
        veloz_activo = 0,
    }
    return state
end

function game.iniciar_partida(state)
    local card_defs = require("data.cards")
    local mazo = {}
    for _, c in pairs(card_defs) do
        table.insert(mazo, { id = c.id, valor = c.valor, color = c.color, dano_base = c.dano_base })
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

    world.nuevo_mundo(state)
    combat.init(state)
    state.fase = "combat"
end

function game.turno_jugador(state, accion, datos)
    if state.fase ~= "combat" then return nil end

    if accion == "jugar" then
        local resultado = combat.jugar_cartas(state, datos.indices)
        if resultado and resultado.dano then
            combat.end_turn(state)
            -- check rival death
            if state.rival.vida <= 0 then
                world.procesar_victoria(state)
                state.fase = "tienda"
                return { type = "victoria", mensaje = "Victoria!" }
            end
            -- turno de IA
            game.turno_ia(state)
            return resultado
        end
        return resultado
    elseif accion == "robar" then
        combat.robar_carta(state, true)
        state.jugador.turno_ultimo = "robo"
        -- robar consume turno (segunda roba)
        combat.end_turn(state)
        -- turno de IA
        game.turno_ia(state)
        return { mensaje = "Robaste una carta" }
    elseif accion == "usar_poder" then
        return game.usar_poder(state, datos.poder_idx, datos.target)
    elseif accion == "usar_objeto" then
        return game.usar_objeto(state, datos.objeto_idx, datos.target)
    end
end

function game.turno_ia(state)
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
            for _, carta in ipairs(cartas) do
                if top and not (carta.valor == top.valor or carta.color == top.color or
                   (type(carta.valor) == "number" and type(top.valor) == "number" and carta.valor == top.valor + 1)) then
                    ok = false; break
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
        for _, r in ipairs(state.relics or {}) do
            if r.on_enemy_card_damage then dano = dano + r.on_enemy_card_damage(cartas[1], state) end
        end

        -- Elusión: reflejar daño
        if state.elusion_activa then
            state.rival.vida = state.rival.vida - dano
            dano = 0
            state.elusion_activa = nil
        end

        state.jugador.vida = state.jugador.vida - dano
    else
        combat.robar_carta(state, false)
    end
end

function game.usar_poder(state, idx, target)
    if not state.poderes[idx] then return { mensaje = "Poder no encontrado" } end
    local poder = state.poderes[idx]
    local def = require("powers.registry")[poder.id]
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

function game.usar_objeto(state, idx, target)
    if not state.objetos[idx] then return { mensaje = "Objeto no encontrado" } end
    local obj = state.objetos[idx]
    local def = require("items.registry")[obj.id]
    if not def then return { mensaje = "Objeto desconocido" } end

    state.items_target = target
    local resultado = def.usar(state)
    table.remove(state.objetos, idx)
    return resultado
end

function game.comprar_tienda(state, idx)
    local shop = require("shop")
    return shop.comprar(state, idx)
end

function game.reroll_tienda(state)
    local shop = require("shop")
    return shop.reroll(state)
end

-- Helper methods on jugador/rival
local entity_methods = {}
function entity_methods:has_status(id)
    return self.status and self.status[id] and self.status[id] > 0
end
function entity_methods:aplicar_status(id, cargas)
    self.status = self.status or {}
    local def = require("status.registry")[id]
    if def and def.on_aplicar then
        cargas = def.on_aplicar(self, cargas, self) or cargas
    end
    if cargas > 0 then
        local max = def and def.max_cargas
        self.status[id] = max and math.min(max, (self.status[id] or 0) + cargas) or (self.status[id] or 0) + cargas
    end
end
function entity_methods:remove_status(id)
    if self.status then
        local def = require("status.registry")[id]
        if def and def.on_remove then def.on_remove(self) end
        self.status[id] = nil
    end
end

-- Attach methods to entities
function game.init_entity_methods(state)
    setmetatable(state.jugador, { __index = entity_methods })
    if state.rival then
        setmetatable(state.rival, { __index = entity_methods })
    end
end

return game
