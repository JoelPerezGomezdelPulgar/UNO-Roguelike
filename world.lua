local world = {}

local COLORS = require("data.colors")

function world.nuevo_mundo(state)
    state.mundo_actual = (state.mundo_actual or 0) + 1
    state.nivel_mundo = (state.nivel_mundo or 0) + 1
    state.nivel_actual = 1
    state.niveles_mundo = 3
    state.es_bonus = false
    state.es_jefe = false
    state.es_tienda = false
    state.en_combate = true
    world.generar_rival(state)
end

function world.generar_rival(state)
    local nivel = state.nivel_actual
    local mundo = state.mundo_actual

    local nombre_rival = "Enemigo " .. nivel
    local vida_base = 30 + (mundo - 1) * 20 + (nivel - 1) * 10
    local rival = {
        id = 2,
        nombre = nombre_rival,
        vida = vida_base,
        vida_max = vida_base,
        mano = {},
        mano_max = 7,
        status = {},
        mano_congelada = {},
        mazo = {},
    }

    -- Generar mazo rival
    for color, _ in pairs(COLORS) do
        for valor = 0, 9 do
            if valor <= math.min(9, mundo + 2) then
                table.insert(rival.mazo, { id = math.random(99999), valor = valor, color = color, dano_base = valor })
            end
        end
    end
    -- shuffle and draw
    for i = #rival.mazo, 2, -1 do
        local j = math.random(i)
        rival.mazo[i], rival.mazo[j] = rival.mazo[j], rival.mazo[i]
    end
    for i = 1, rival.mano_max do
        if #rival.mazo > 0 then
            table.insert(rival.mano, table.remove(rival.mazo))
        end
    end

    state.rival = rival
    state.mazo_rival = rival.mazo
    state.mesa = {}
end

function world.avanzar_nivel(state)
    state.nivel_actual = state.nivel_actual + 1
    state.en_combate = true
    state.es_tienda = false
    state.es_bonus = false
    state.es_jefe = false

    if state.nivel_actual > state.niveles_mundo then
        -- Bonus antes del jefe (cada 2 mundos)
        if state.mundo_actual % 2 == 0 and not state.bonus_usado then
            state.es_bonus = true
            state.bonus_options = world.generar_bonus()
            state.bonus_usado = true
            return "bonus"
        else
            state.es_jefe = true
            world.generar_jefe(state)
            return "boss"
        end
    else
        world.generar_rival(state)
        return "combat"
    end
end

function world.generar_bonus()
    local opciones = {
        { id = "deidad", nombre = "Deidad del entrenamiento",
          descripcion = "Elige un poder (cuesta oro, comida o cartas)",
          acciones = {"dar_comida", "dar_dinero", "dar_cartas"} },
        { id = "altar", nombre = "Altar",
          descripcion = "Sacrifica un ser por reliquia o poder a escoger entre 3",
          acciones = {"sacrificar_ser"} },
        { id = "biblioteca", nombre = "Biblioteca",
          descripcion = "Descarta N cartas, roba N nuevas (máx 4)",
          acciones = {"descartar_robar"} },
        { id = "apuesta", nombre = "Apuesta",
          descripcion = "Duplica oro, triplica, pierde mitad o todo",
          acciones = {"apostar"} },
        { id = "forja", nombre = "Forja",
          descripcion = "Mejora una carta +1 daño (máx +2)",
          acciones = {"mejorar_carta"} },
    }
    local disponibles = {}
    local idx1 = math.random(#opciones)
    local idx2
    repeat idx2 = math.random(#opciones) until idx2 ~= idx1
    table.insert(disponibles, opciones[idx1])
    table.insert(disponibles, opciones[idx2])
    return disponibles
end

function world.generar_jefe(state)
    local mundo = state.mundo_actual
    local vida_base = 80 + (mundo - 1) * 40
    local jefe = {
        id = 2,
        nombre = "Jefe del Mundo " .. mundo,
        vida = vida_base,
        vida_max = vida_base,
        mano = {},
        mano_max = 9,
        status = {},
        mano_congelada = {},
        mazo = {},
    }

    -- Mazo especializado del jefe
    local colores_jefe = {"Rojo", "Azul", "Verde", "Amarillo"}
    for _, color in ipairs(colores_jefe) do
        for valor = 0, 9 do
            local n = math.random(1, 3)
            for _ = 1, n do
                table.insert(jefe.mazo, { id = math.random(99999), valor = valor, color = color, dano_base = valor })
            end
        end
    end
    for i = #jefe.mazo, 2, -1 do
        local j = math.random(i)
        jefe.mazo[i], jefe.mazo[j] = jefe.mazo[j], jefe.mazo[i]
    end
    for i = 1, jefe.mano_max do
        if #jefe.mazo > 0 then
            table.insert(jefe.mano, table.remove(jefe.mazo))
        end
    end

    -- Jefes avanzados tienen seres
    if mundo >= 3 then
        jefe.tiene_ser = true
    end

    state.rival = jefe
    state.mazo_rival = jefe.mazo
    state.mesa = {}
end

function world.procesar_victoria(state)
    -- Cálculo de oro
    local oro_vida = math.floor(state.jugador.vida / 10)
    local oro_inventario = math.floor((state.oro or 0) / 3)
    state.oro = (state.oro or 0) + oro_vida + oro_inventario

    -- Si es jefe, recompensa especial
    if state.es_jefe then
        state.jefe_derrotado = (state.jefe_derrotado or 0) + 1
        -- Desbloquear seres en cuartel
        if state.jefe_derrotado >= 1 then
            -- unlock being types progressively
        end
    end

    state.en_combate = false
    state.es_tienda = true

    -- Reiniciar estado de combate
    state.turno_actual = 1
    state.aturdido = false
end

function world.procesar_derrota(state)
    -- Contrato maldito
    for _, r in ipairs(state.relics or {}) do
        if r.id == "contrato_maldito" then
            if r.on_muerte(state) then
                state.en_combate = true
                return "revivido"
            end
        end
    end
    -- Phoenix
    if state.phoenix_evita and state.phoenix_evita > 0 then
        state.phoenix_evita = state.phoenix_evita - 1
        if state.phoenix_penalidad == "mitad_dinero" then
            state.oro = math.floor((state.oro or 0) / 2)
        elseif state.phoenix_penalidad == "todo_dinero_y_habilidad" then
            state.oro = 0
            if #state.poderes > 0 then table.remove(state.poderes, math.random(#state.poderes)) end
        end
        if state.phoenix_on_muerte then state.phoenix_on_muerte(state) end
        state.jugador.vida = state.jugador.vida_max
        return "revivido"
    end
    return "game_over"
end

return world
