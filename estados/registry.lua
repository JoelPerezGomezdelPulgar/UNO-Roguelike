local status_effects = {}

-- QUEMADO
status_effects.quemado = {
    id = "quemado",
    nombre = "Quemado",
    max_cargas = nil,
    on_turn_end = function(state, cargas, portador)
        local dmg = cargas
        portador.vida = portador.vida - dmg
        return cargas - 1
    end,
    on_aplicar = function(state, cargas, portador)
        if portador:tiene_estados("mojado") then
            portador:eliminar_estados("mojado")
            return 0
        end
        return cargas
    end,
    on_remove = function(state, portador)
        if portador:tiene_estados("mojado") then
            portador:eliminar_estados("mojado")
        end
    end,
}

-- MOJADO
status_effects.mojado = {
    id = "mojado",
    nombre = "Mojado",
    max_cargas = 10,
    on_turn_start = function(state, cargas, portador)
        if math.random() < 0.2 then return 0 end
        return cargas
    end,
    on_attack = function(state, cargas, portador, target)
        if math.random() < 0.02 * cargas then
            return "fail"
        end
    end,
    on_aplicar = function(state, cargas, portador)
        if portador:tiene_estados("quemado") then
            portador:eliminar_estados("quemado")
            return 0
        end
        if portador:tiene_estados("veneno") then
            portador:eliminar_estados("veneno")
        end
        return cargas
    end,
}

-- VENENO
status_effects.veneno = {
    id = "veneno",
    nombre = "Veneno",
    max_cargas = nil,
    on_turn_end = function(state, cargas, portador)
        local dmg = math.floor(portador.vida_max * 0.01 * cargas)
        if portador:tiene_estados("descomposicion") then
            dmg = dmg + (portador.status.descomposicion or 0)
        end
        portador.vida = portador.vida - dmg
        return cargas
    end,
    on_descomposicion_tick = function(state, cargas, portador)
        return 1
    end,
}

-- DESCOMPOSICIÓN
status_effects.descomposicion = {
    id = "descomposicion",
    nombre = "Descomposición",
    max_cargas = nil,
    on_turn_end = function(state, cargas, portador)
        local extra = 0
        if portador:tiene_estados("veneno") then extra = cargas end
        local dmg = cargas * 2 + extra
        portador.vida = portador.vida - dmg
        return math.max(0, cargas - 2)
    end,
}

-- ATURDIDO
status_effects.aturdido = {
    id = "aturdido",
    nombre = "Aturdido",
    max_cargas = nil,
    on_turn_start = function(state, cargas, portador)
        state.aturdido = cargas
        return cargas - 1
    end,
    on_end = function(state, cargas, portador)
        if cargas <= 0 then state.aturdido = 0 end
    end,
}

-- CONGELADO
status_effects.congelado = {
    id = "congelado",
    nombre = "Congelado",
    max_cargas = nil,
    on_aplicar = function(state, cargas, portador, carta_idx)
        portador.mano_congelada[carta_idx] = (portador.mano_congelada[carta_idx] or 0) + 1
    end,
    on_turn_start = function(state, cargas, portador)
        for i = #portador.mano_congelada, 1, -1 do
            portador.mano_congelada[i] = portador.mano_congelada[i] - 1
            if portador.mano_congelada[i] <= 0 then
                table.remove(portador.mano_congelada, i)
            end
        end
        return cargas - 1
    end,
}

return status_effects
