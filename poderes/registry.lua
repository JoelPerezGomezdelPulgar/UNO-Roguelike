local powers = {}

-- Helper: create cooldown tracker
local function C(val) return { type = "combates", max = val, current = 0 } end
local function T(val) return { type = "turnos", max = val, current = 0 } end

powers.haz_oscuridad = {
    id = "haz_oscuridad", nombre = "Haz de oscuridad",
    descripcion = "Inflige daño = cartas en tu mano",
    cooldown = C(1),
    activar = function(state)
        state.rival.vida = math.max(0, state.rival.vida - (#state.jugador.mano * 5))
        return { dano = #state.jugador.mano * 5 }
    end,
}

powers.haz_luz = {
    id = "haz_luz", nombre = "Haz de luz",
    descripcion = "Recupera vida = cartas en tu mano",
    cooldown = C(1),
    activar = function(state)
        local curacion = #state.jugador.mano * 1
        state.jugador.vida = math.min(state.jugador.vida_max, state.jugador.vida + curacion)
        return { mensaje = "+" .. curacion .. " vida" }
    end,
}

powers.absorcion_vida = {
    id = "absorcion_vida", nombre = "Absorción de vida",
    descripcion = "50% del daño infligido se recupera como vida durante 1 turno",
    cooldown = T(5),
    activar = function(state)
        state.absorcion_vida_activa = 1
        return { mensaje = "Absorción de vida activada por 1 turno" }
    end,
}

powers.furia_berserker = {
    id = "furia_berserker", nombre = "Furia Berserker",
    descripcion = "+2 daño a todas las cartas durante 1 turno",
    cooldown = T(3),
    activar = function(state)
        state.furia_activa = 2
        return { mensaje = "+2 daño a todas las cartas por 1 turno" }
    end,
}

powers.golpe_decisivo = {
    id = "golpe_decisivo", nombre = "Golpe Decisivo",
    descripcion = "+5 daño a la primera carta que juegues",
    cooldown = T(3),
    activar = function(state)
        state.golpe_decisivo = 5
        return { mensaje = "Primera carta +5 daño" }
    end,
}

powers.rayo_electricidad = {
    id = "rayo_electricidad", nombre = "Rayo de electricidad",
    descripcion = "25% vida máxima del rival (33% si está mojado)",
    cooldown = C(1),
    activar = function(state)
        if state.rival:tiene_estados("mojado") then
            local dmg = math.floor(state.rival.vida_max * 0.33)
            state.rival.vida = state.rival.vida - dmg
            return { dano = dmg }
        else
            local dmg = math.floor(state.rival.vida_max * 0.25)
            state.rival.vida = state.rival.vida - dmg
            return { dano = dmg }
        end
    end,
}

powers.gas_venenoso = {
    id = "gas_venenoso", nombre = "Gas venenoso",
    descripcion = "Envenena al rival",
    cooldown = C(2),
    activar = function(state)
        state.rival:aplicar_estados("veneno", 5)
        return { mensaje = "Rival envenenado" }
    end,
}

powers.cuchilla_hidraulica = {
    id = "cuchilla_hidraulica", nombre = "Cuchilla hidráulica",
    descripcion = "20 de daño y moja al rival",
    cooldown = T(6),
    activar = function(state)
        state.rival:aplicar_estados("mojado", 5)
        state.rival.vida = state.rival.vida - 20
        return { dano = 20 }
    end,
}

powers.bloqueo_perfecto = {
    id = "bloqueo_perfecto", nombre = "Bloqueo perfecto",
    descripcion = "Reduce daño recibido en 2 durante todo el combate",
    cooldown = C(2),
    activar = function(state)
        state.reduccion_dano = (state.reduccion_dano or 0) + 2
        return { mensaje = "Daño recibido -2" }
    end,
}

powers.elusion = {
    id = "elusion", nombre = "Elusión",
    descripcion = "Refleja el daño completo al rival en el siguiente turno",
    cooldown = T(4),
    activar = function(state)
        state.elusion_activa = true
        return { mensaje = "Próximo ataque reflejado" }
    end,
}

powers.bola_fuego = {
    id = "bola_fuego", nombre = "Bola de fuego",
    descripcion = "20 de daño y quema al rival",
    cooldown = T(6),
    activar = function(state)
        state.rival:aplicar_estados("quemado", 5)
        state.rival.vida = state.rival.vida - 20
        return { dano = 20 }
    end,
}

powers.creacion_magica_simple = {
    id = "creacion_magica_simple", nombre = "Creación mágica simple",
    descripcion = "Añade 3 cartas temporales, repetitivas y fantasmales del número o color que escojas",
    cooldown = C(1),
    activar = function(state, target)
        -- target = { type = "numero" or "color", value = ... }
        for i = 1, 3 do
            local carta = target.type == "numero"
                and { valor = target.value, color = "Rojo", efectos = {"temporal","repetitivo","fantasmal"}, dano_base = target.value }
                or { valor = 5, color = target.value, efectos = {"temporal","repetitivo","fantasmal"}, dano_base = 5 }
            carta.id = "temp_" .. math.random(99999)
            table.insert(state.jugador.mano, carta)
        end
        return { mensaje = "3 cartas creadas" }
    end,
}

powers.creacion_magica_avanzada = {
    id = "creacion_magica_avanzada", nombre = "Creación mágica avanzada",
    descripcion = "1 carta del número y color que escojas con efecto aleatorio",
    cooldown = C(3),
    activar = function(state, target)
        local efectos_posibles = {"quemado", "mojado", "veneno", "temporal", "repetitivo", "incesante", "fantasmal", "veloz"}
        local carta = { valor = target.valor, color = target.color, efectos = {efectos_posibles[math.random(#efectos_posibles)]}, dano_base = target.valor }
        carta.id = "temp_" .. math.random(99999)
        table.insert(state.jugador.mano, carta)
        return { mensaje = "Carta creada con efecto " .. carta.efectos[1] }
    end,
}

powers.putrefaccion = {
    id = "putrefaccion", nombre = "Putrefacción",
    descripcion = "Convierte una carta de tu mano a descompuesta",
    cooldown = C(1),
    activar = function(state, target_idx)
        if target_idx and state.jugador.mano[target_idx] then
            state.jugador.mano[target_idx].efectos = state.jugador.mano[target_idx].efectos or {}
            table.insert(state.jugador.mano[target_idx].efectos, "descompuesta")
            return { mensaje = "Carta descompuesta" }
        end
        return { mensaje = "Selecciona una carta" }
    end,
}

powers.deterioro = {
    id = "deterioro", nombre = "Deterioro",
    descripcion = "10 de daño y 4 cargas de descomposición al rival",
    cooldown = T(3),
    activar = function(state)
        state.rival:aplicar_estados("descomposicion", 4)
        return { dano = 10 }
    end,
}

powers.escarcha = {
    id = "escarcha", nombre = "Escarcha",
    descripcion = "Congela una carta aleatoria del rival 1 turno",
    cooldown = T(4),
    activar = function(state)
        if #state.rival.mano > 0 then
            local idx = math.random(#state.rival.mano)
            state.rival.mano_congelada[idx] = (state.rival.mano_congelada[idx] or 0) + 1
            return { mensaje = "Carta rival congelada" }
        end
        return { mensaje = "Rival no tiene cartas" }
    end,
}

powers.martillo_juicio = {
    id = "martillo_juicio", nombre = "Martillo del juicio",
    descripcion = "20 x nivel del mundo de daño",
    cooldown = T(5),
    activar = function(state)
        state.rival.vida = state.rival.vida - (20 * (state.mundo_nivel or 1))
        return { dano = 20 * (state.mundo_nivel or 1) }
    end,
}
---------------------------------------------------------------- HACEN FALTA LOS SERES ----------------------------------------------------------------
powers.invocacion_menor = {
    id = "invocacion_menor", nombre = "Invocación menor",
    descripcion = "Invoca un ser de nivel 1 temporal",
    cooldown = C(6),
    activar = function(state)
        return { type = "invocar_ser", nivel = 1, temporal = true }
    end,
}

---------------------------------------------------------------- HACEN FALTA LOS SERES ----------------------------------------------------------------

powers.entrenamiento = {
    id = "entrenamiento", nombre = "Entrenamiento",
    descripcion = "Sube de nivel a un ser",
    cooldown = C(6),
    activar = function(state, being_idx)
        if being_idx and state.seres[being_idx] then
            state.seres[being_idx].nivel = math.min(3, (state.seres[being_idx].nivel or 1) + 1)
            return { mensaje = state.seres[being_idx].nombre .. " subió a nivel " .. state.seres[being_idx].nivel }
        end
        return { mensaje = "Selecciona un ser" }
    end,
}

---------------------------------------------------------------- HACEN FALTA LOS SERES ----------------------------------------------------------------

powers.redistribucion = {
    id = "redistribucion", nombre = "Redistribución",
    descripcion = "Baraja tu mano en el mazo y roba 7 cartas",
    cooldown = C(1),
    activar = function(state)
        for _, c in ipairs(state.jugador.mano) do table.insert(state.mazo_jugador, c) end
        state.jugador.mano = {}
        for i = 1, 7 do
            if #state.mazo_jugador > 0 then
                local idx = math.random(#state.mazo_jugador)
                table.insert(state.jugador.mano, table.remove(state.mazo_jugador, idx))
            end
        end
        return { mensaje = "Mano redistribuida" }
    end,
}

powers.marcaje = {
    id = "marcaje", nombre = "Marcaje",
    descripcion = "Selecciona un número, todas las cartas con ese número hacen +3 de daño",
    cooldown = C(1),
    activar = function(state, target_numero)
        if target_numero == nil then
            return { mensaje = "Selecciona una carta de tu mano" }
        end
        state.numero_marcado = target_numero
        return { mensaje = "Número " .. target_numero .. " marcado (+3 daño)" }
    end,
}

powers.rafaga_viento = {
    id = "rafaga_viento", nombre = "Ráfaga de viento",
    descripcion = "Devuelve 2 cartas al mazo, roba otras 2",
    cooldown = T(5),
    activar = function(state, indices)
        if not indices or #indices ~= 2 then return { mensaje = "Selecciona 2 cartas" } end
        for i = #indices, 1, -1 do
            local carta = table.remove(state.jugador.mano, indices[i])
            if carta then table.insert(state.mazo_jugador, carta) end
        end
        for i = 1, 2 do
            if #state.mazo_jugador > 0 then
                table.insert(state.jugador.mano, table.remove(state.mazo_jugador))
            end
        end
        return { mensaje = "2 cartas intercambiadas" }
    end,
}

return powers
