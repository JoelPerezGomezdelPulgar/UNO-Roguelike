local items = {}

items.lagrima_fenix = {
    id = "lagrima_fenix", nombre = "Lágrima de Fénix",
    descripcion = "Cura 100 de vida (se reduce en 10 por cada uso)",
    precio_base = 8,
    usar = function(state)
        local usos = state.lagrimas_usadas or 0
        local curacion = math.max(10, 100 - usos * 10)
        state.jugador.vida = math.min(state.jugador.vida_max, state.jugador.vida + curacion)
        state.lagrimas_usadas = (state.lagrimas_usadas or 0) + 1
        return { mensaje = "+" .. curacion .. " vida" }
    end,
}

local function transformar_color(state, color)
    for _, i in ipairs(state.objetos_objetivo or {}) do
        if state.jugador.mano[i] then
            state.jugador.mano[i].color = color
        end
    end
    return { mensaje = "Cartas transformadas a " .. color }
end

items.brasero_ardiente = { id = "brasero_ardiente", nombre = "Brasero Ardiente", descripcion = "Transforma 2 cartas seleccionadas en rojas", precio_base = 5, usar = function(s) return transformar_color(s, "Rojo") end }
items.agua_bendita = { id = "agua_bendita", nombre = "Agua bendita", descripcion = "Transforma 2 cartas seleccionadas en azules", precio_base = 5, usar = function(s) return transformar_color(s, "Azul") end }
items.ofrenda_sol = { id = "ofrenda_sol", nombre = "Ofrenda al sol", descripcion = "Transforma 2 cartas seleccionadas en amarillas", precio_base = 5, usar = function(s) return transformar_color(s, "Amarillo") end }
items.brote_yggdrasil = { id = "brote_yggdrasil", nombre = "Brote de Yggdrasil", descripcion = "Transforma 2 cartas seleccionadas en verdes", precio_base = 5, usar = function(s) return transformar_color(s, "Verde") end }

items.moneda_cambio = {
    id = "moneda_cambio", nombre = "Moneda de cambio",
    descripcion = "Intercambia el número de 2 cartas seleccionadas",
    precio_base = 6,
    usar = function(state)
        local t = state.objetos_objetivo or {}
        if #t >= 2 then
            local v = state.jugador.mano[t[1]].valor
            state.jugador.mano[t[1]].valor = state.jugador.mano[t[2]].valor
            state.jugador.mano[t[2]].valor = v
        end
        return { mensaje = "Números intercambiados" }
    end,
}

items.tinta_cambio = {
    id = "tinta_cambio", nombre = "Tinta de cambio",
    descripcion = "Intercambia el color de 2 cartas seleccionadas",
    precio_base = 6,
    usar = function(state)
        local t = state.objetos_objetivo or {}
        if #t >= 2 then
            local c = state.jugador.mano[t[1]].color
            state.jugador.mano[t[1]].color = state.jugador.mano[t[2]].color
            state.jugador.mano[t[2]].color = c
        end
        return { mensaje = "Colores intercambiados" }
    end,
}

items.martillo_roto = {
    id = "martillo_roto", nombre = "Martillo roto",
    descripcion = "25% mejorar carta, 5% eliminar efectos",
    precio_base = 4,
    usar = function(state)
        local t = state.objetos_objetivo or {}
        if #t >= 1 then
            local carta = state.jugador.mano[t[1]]
            if math.random() < 0.25 then
                carta.dano_base = (carta.dano_base or carta.valor) + 2
                if math.random() < 0.05 then carta.efectos = nil end
                return { mensaje = "Carta mejorada" }
            end
        end
        return { mensaje = "Nada sucedió" }
    end,
}

items.brebaje_barbaro = {
    id = "brebaje_barbaro", nombre = "Brebaje bárbaro",
    descripcion = "+2 daño durante 1 turno",
    precio_base = 3,
    usar = function(state)
        state.furia_activa = (state.furia_activa or 0) + 2
        return { mensaje = "+2 daño este turno" }
    end,
}

items.caja_pandora = {
    id = "caja_pandora", nombre = "Caja de pandora",
    descripcion = "Inflige efecto de estado negativo aleatorio al rival",
    precio_base = 7,
    usar = function(state)
        local efectos = {"quemado", "mojado", "veneno", "descomposicion"}
        local e = efectos[math.random(#efectos)]
        state.rival:aplicar_estados(e, 5)
        return { mensaje = "Rival sufre " .. e }
    end,
}

items.saco_viveres = {
    id = "saco_viveres", nombre = "Saco de víveres",
    descripcion = "Genera 2 comida",
    precio_base = 3,
    usar = function(state)
        state.comida = (state.comida or 0) + 2
        return { mensaje = "+2 comida" }
    end,
}

items.fragmento_estelar = {
    id = "fragmento_estelar", nombre = "Fragmento estelar",
    descripcion = "Destruye 2 cartas seleccionadas de tu mano",
    precio_base = 4,
    usar = function(state)
        local t = state.objetos_objetivo or {}
        table.sort(t, function(a,b) return a > b end)
        for _, i in ipairs(t) do
            table.remove(state.jugador.mano, i)
        end
        return { mensaje = "Cartas destruidas" }
    end,
}

items.espejo_polvoriento = {
    id = "espejo_polvoriento", nombre = "Espejo polvoriento",
    descripcion = "Añade la carta de la mesa a tu mano con atributo temporal",
    precio_base = 5,
    usar = function(state)
        if #state.mesa > 0 then
            local carta = state.mesa[#state.mesa]
            local copia = { id = "copy_" .. math.random(99999), valor = carta.valor, color = carta.color, dano_base = carta.valor, efectos = {"temporal"} }
            table.insert(state.jugador.mano, copia)
            return { mensaje = "Carta copiada a tu mano" }
        end
        return { mensaje = "No hay carta en mesa" }
    end,
}

items.carbon_ardiente = {
    id = "carbon_ardiente", nombre = "Carbón ardiente",
    descripcion = "5 cargas de quemado al rival",
    precio_base = 4,
    usar = function(state)
        state.rival:aplicar_estados("quemado", 5)
        return { mensaje = "Rival quemado" }
    end,
}

items.perla_proteccion = {
    id = "perla_proteccion", nombre = "Perla de protección",
    descripcion = "Reduce a 0 el daño del siguiente turno del rival",
    precio_base = 8,
    usar = function(state)
        state.perla_proteccion = true
        return { mensaje = "Protección activada" }
    end,
}

items.totem_menor = {
    id = "totem_menor", nombre = "Tótem menor",
    descripcion = "Elimina todos tus efectos de estado actuales",
    precio_base = 6,
    usar = function(state)
        for k, _ in pairs(state.jugador.status) do state.jugador.status[k] = nil end
        return { mensaje = "Efectos eliminados" }
    end,
}

return items
