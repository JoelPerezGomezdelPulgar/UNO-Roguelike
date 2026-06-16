local relics = {}

relics.trebol_4_hojas = {
    id = "trebol_4_hojas", nombre = "Trébol de 4 hojas",
    rareza = "comun", descripcion = "Todos los 7 tienen +2 de daño",
    on_card_damage = function(card, state) if card.valor == 7 then return 2 end return 0 end,
}

relics.antidoto_debil = {
    id = "antidoto_debil", nombre = "Antídoto débil",
    rareza = "comun", descripcion = "25% de eliminar efectos de estado al inicio del turno",
    on_turn_start = function(state)
        if math.random() < 0.25 then
            for status_id, _ in pairs(state.jugador.status) do
                state.jugador.status[status_id] = nil
            end
        end
    end,
}

relics.cornucopia = {
    id = "cornucopia", nombre = "Cornucopia",
    rareza = "comun", descripcion = "Al jugar escalera, genera comida",
    on_escalera = function(state) return 1 end,
}

relics.pergamino_leyendas = {
    id = "pergamino_leyendas", nombre = "Pergamino de leyendas",
    rareza = "raro", descripcion = "0.33 de multiplicador por nivel de tus seres",
    on_mult = function(state)
        local total = 0
        for _, being in ipairs(state.beings) do total = total + (being.nivel or 0) end
        return 1 + total * 0.33
    end,
}

relics.colgante_rubi = { id = "colgante_rubi", nombre = "Colgante de rubí", rareza = "comun", descripcion = "+1 daño a cartas rojas", on_card_damage = function(c, s) return c.color == "Rojo" and 1 or 0 end }
relics.colgante_esmeralda = { id = "colgante_esmeralda", nombre = "Colgante de esmeralda", rareza = "comun", descripcion = "+1 daño a cartas verdes", on_card_damage = function(c, s) return c.color == "Verde" and 1 or 0 end }
relics.colgante_zafiro = { id = "colgante_zafiro", nombre = "Colgante de zafiro", rareza = "comun", descripcion = "+1 daño a cartas azules", on_card_damage = function(c, s) return c.color == "Azul" and 1 or 0 end }
relics.colgante_ambar = { id = "colgante_ambar", nombre = "Colgante de ámbar", rareza = "comun", descripcion = "+1 daño a cartas amarillas", on_card_damage = function(c, s) return c.color == "Amarillo" and 1 or 0 end }

relics.gema_orden = {
    id = "gema_orden", nombre = "Gema del orden",
    rareza = "raro", descripcion = "x2 si tienes escalera en mano sin jugar",
    on_pre_mult = function(state) if state:has_straight_in_hand() then return 2 end return 1 end,
}

relics.daga_sangre = {
    id = "daga_sangre", nombre = "Daga de sangre",
    rareza = "raro", descripcion = "+3 daño a cartas rojas",
    on_card_damage = function(c, s) return c.color == "Rojo" and 3 or 0 end,
}

relics.mano_midas = {
    id = "mano_midas", nombre = "Mano de Midas",
    rareza = "raro", descripcion = "+1 oro al jugar carta verde",
    on_play_card = function(card, state) if card.color == "Verde" then return { oro = 1 } end end,
}

relics.concha_triton = {
    id = "concha_triton", nombre = "Concha de tritón",
    rareza = "comun", descripcion = "Cartas azules aplican mojado",
    on_card_played = function(card, state)
        if card.color == "Azul" then
            state.rival:aplicar_status("mojado", 3)
        end
    end,
}

relics.ojo_ra = {
    id = "ojo_ra", nombre = "Ojo de Ra",
    rareza = "raro", descripcion = "+0.1 mult por carta amarilla jugada, se reinicia cada combate",
    on_init_combat = function(state) state.ojo_ra_mult = 0 end,
    on_play_card = function(card, state) if card.color == "Amarillo" then state.ojo_ra_mult = state.ojo_ra_mult + 0.1 end end,
    on_mult = function(state) return 1 + (state.ojo_ra_mult or 0) end,
}

relics.caliz_elementos = {
    id = "caliz_elementos", nombre = "Cáliz de elementos",
    rareza = "raro", descripcion = "+1 precio venta por cada efecto de estado infligido",
    on_aplicar_status = function(state) state.caliz_precio = (state.caliz_precio or 0) + 1 end,
}

relics.puno_avaricia = {
    id = "puno_avaricia", nombre = "Puño de la avaricia",
    rareza = "comun", descripcion = "+1 daño por cada 4 de oro",
    on_card_damage = function(c, s) return math.floor((s.oro or 0) / 4) end,
}

relics.blason_elemental = {
    id = "blason_elemental", nombre = "Blasón elemental",
    rareza = "legendario",
    descripcion = "+2 daño, cartas se vuelven descompuestas, x0.1 mult permanente cada 6 cartas, +1 oro cada 3 cartas, cartas cuentan como todos los colores",
    on_card_damage = function(c, s) return 2 end,
    on_play_card = function(card, state)
        card.efectos = card.efectos or {}
        table.insert(card.efectos, "descompuesta")
        state.blason_contador = (state.blason_contador or 0) + 1
        if state.blason_contador % 3 == 0 then return { oro = 1 } end
    end,
    on_mult_permanent = function(state)
        local n = state.blason_contador or 0
        return 1 + math.floor(n / 6) * 0.1
    end,
    on_color = function() return { "Rojo", "Verde", "Azul", "Amarillo" } end,
}

relics.escudo_eter = {
    id = "escudo_eter", nombre = "Escudo de éter",
    rareza = "comun", descripcion = "Reduce en 1 el daño de cartas enemigas",
    on_enemy_card_damage = function(c, s) return -1 end,
}

relics.anillo_vacio = {
    id = "anillo_vacio", nombre = "Anillo del vacío",
    rareza = "raro", descripcion = "Reduce aturdimiento en 1 turno",
    on_aturdimiento = function(state) return -1 end,
}

relics.contrato_maldito = {
    id = "contrato_maldito", nombre = "Contrato maldito",
    rareza = "legendario", descripcion = "Al morir, sacrifica al ser de nivel más bajo",
    on_muerte = function(state)
        local lowest = nil
        for _, being in ipairs(state.beings) do
            if not lowest or (being.nivel or 0) < (lowest.nivel or 0) then
                lowest = being
            end
        end
        if lowest then
            for i, b in ipairs(state.beings) do
                if b == lowest then table.remove(state.beings, i); break end
            end
            state.jugador.vida = state.jugador.vida_max
            return true
        end
        return false
    end,
}

relics.gema_caos = {
    id = "gema_caos", nombre = "Gema del caos",
    rareza = "raro", descripcion = "Al jugar trío, aplica efecto negativo aleatorio",
    on_trio = function(state)
        local efectos = {"quemado", "veneno", "descomposicion", "mojado"}
        state.rival:aplicar_status(efectos[math.random(#efectos)], 3)
    end,
}

relics.guantes_seda = {
    id = "guantes_seda", nombre = "Guantes de seda",
    rareza = "comun", descripcion = "+1 daño a cartas robadas",
    on_card_damage = function(c, s) return c.es_robada and 1 or 0 end,
}

relics.amuleto_eco = {
    id = "amuleto_eco", nombre = "Amuleto de eco",
    rareza = "legendario", descripcion = "La primera carta que juegues se reactiva 2 veces",
    on_first_card = function(card, state)
        for i = 1, 2 do
            -- re-play the card logic
            state:replay_card(card)
        end
    end,
}

relics.lente_aumento = {
    id = "lente_aumento", nombre = "Lente de aumento",
    rareza = "comun", descripcion = "Ver la mano del rival",
    on_combat_start = function(state) state.ver_mano_rival = true end,
}

relics.piedra_iman = {
    id = "piedra_iman", nombre = "Piedra imán",
    rareza = "comun", descripcion = "+1 daño si todas las cartas jugadas son del mismo color que la última",
    on_post_mult = function(state, cartas)
        if #cartas < 2 then return 1 end
        local color = cartas[#cartas].color
        for _, c in ipairs(cartas) do
            if c.color ~= color then return 1 end
        end
        return 1 + (#cartas * 1)
    end,
}

relics.carta_marcada = {
    id = "carta_marcada", nombre = "Carta marcada",
    rareza = "raro", descripcion = "Primera robada del combate la puedes escoger",
    on_first_draw = function(state)
        state.carta_marcada_activa = true
    end,
}

relics.sello_sangre = {
    id = "sello_sangre", nombre = "Sello de sangre",
    rareza = "comun", descripcion = "+1 vida por carta jugada",
    on_play_card = function(c, s) s.jugador.vida = math.min(s.jugador.vida_max, s.jugador.vida + 1) end,
}

relics.bolsa_arena = {
    id = "bolsa_arena", nombre = "Bolsa de arena",
    rareza = "comun", descripcion = "-1 tamaño de mano para el rival",
    on_combat_start = function(state) state.rival.mano_max = (state.rival.mano_max or 7) - 1 end,
}

relics.colmillo_plata = {
    id = "colmillo_plata", nombre = "Colmillo de plata",
    rareza = "comun", descripcion = "+4 daño a cartas con número 0",
    on_card_damage = function(c, s) return c.valor == 0 and 4 or 0 end,
}

relics.pendulo_lunar = {
    id = "pendulo_lunar", nombre = "Péndulo lunar",
    rareza = "raro", descripcion = "Al jugar escalera de color, genera objeto aleatorio",
    on_escalera_color = function(state)
        return { type = "generar_objeto", count = 1 }
    end,
}

relics.ala_cuervo = {
    id = "ala_cuervo", nombre = "Ala de cuervo",
    rareza = "comun", descripcion = "+1 daño por carta en tu mano",
    on_card_damage = function(c, s) return #s.jugador.mano end,
}

relics.espejo_reflector = {
    id = "espejo_reflector", nombre = "Espejo reflector",
    rareza = "raro", descripcion = "Si el rival juega mano de color, recibe 25% del daño infligido",
    on_rival_color_hand = function(state, dano)
        state.rival.vida = state.rival.vida - math.floor(dano * 0.25)
    end,
}

return relics
