local beings = {}

local function level_req(tipo, nivel_actual)
    if tipo == "deidad" then
        if nivel_actual == 1 then return { dano_infligido = 500 }
        elseif nivel_actual == 2 then return { dano_infligido = 1000 } end
    elseif tipo == "criatura" then
        if nivel_actual == 1 then return { comida = 4 }
        elseif nivel_actual == 2 then return { comida = 8 } end
    elseif tipo == "heroe" then
        if nivel_actual == 1 then return { combates = 4 }
        elseif nivel_actual == 2 then return { combates = 8 } end
    end
    return nil
end

local function make_being(def)
    def.tipo = def.tipo_hint or "deidad"
    def.subir_nivel_req = level_req
    for lvl = 1, 3 do
        def.niveles = def.niveles or {}
        if not def.niveles[lvl] then
            def.niveles[lvl] = { positivo = function() end, negativo = function() end }
        end
    end
    return def
end

-- PHOENIX (Deidad)
beings.phoenix = make_being({
    id = "phoenix", nombre = "Phoenix", tipo_hint = "deidad",
    descripcion = "Evita la muerte",
    niveles = {
        [1] = {
            positivo = function(s) s.phoenix_evita = 1; s.phoenix_penalidad = "mitad_dinero" end,
            negativo = function(s) end,
        },
        [2] = {
            positivo = function(s) s.phoenix_evita = 1; s.phoenix_penalidad = "todo_dinero_y_habilidad" end,
            negativo = function(s) end,
        },
        [3] = {
            positivo = function(s)
                s.phoenix_evita = 2
                s.phoenix_al_morir = function()
                    s.oro = s.oro + 10
                    -- escoger poder entre 3 aleatorios
                end
            end,
            negativo = function(s) end,
        },
    },
})

-- MINOTAURO (Criatura)
beings.minotauro = make_being({
    id = "minotauro", nombre = "Minotauro", tipo_hint = "criatura",
    descripcion = "Aumenta daño pero recibes más daño",
    niveles = {
        [1] = { positivo = function(s) s.minotauro_dano_extra = 3 end, negativo = function(s) s.dano_recibido_extra = 2 end },
        [2] = { positivo = function(s) s.minotauro_dano_extra = 4 end, negativo = function(s) s.dano_recibido_extra = 5 end },
        [3] = { positivo = function(s) s.mult_dano = (s.mult_dano or 1) * 3 end, negativo = function(s) end },
    },
})

-- ZEUS (Deidad)
beings.zeus = make_being({
    id = "zeus", nombre = "Zeus", tipo_hint = "deidad",
    descripcion = "Cartas amarillas = daño eléctrico",
    niveles = {
        [1] = { positivo = function(s) end, negativo = function(s) s.dano_por_turno = (s.dano_por_turno or 0) + 2 end },
        [2] = { positivo = function(s) s.dano_electrico_extra = 1 end, negativo = function(s) s.dano_por_turno = (s.dano_por_turno or 0) + 4 end },
        [3] = { positivo = function(s) s.dano_electrico_extra = 3 end, negativo = function(s) end },
    },
})

-- DRAGÓN (Criatura)
beings.dragon = make_being({
    id = "dragon", nombre = "Dragón", tipo_hint = "criatura",
    descripcion = "Rojo/Amarillo +daño, Verde/Azul -daño",
    niveles = {
        [1] = { positivo = function(s) s.dragon_bonus = { Rojo = 1, Amarillo = 1, Verde = -1, Azul = -1 } end, negativo = function(s) end },
        [2] = { positivo = function(s) s.dragon_bonus = { Rojo = 2, Amarillo = 2, Verde = -3, Azul = -3 } end, negativo = function(s) end },
        [3] = { positivo = function(s) s.dragon_bonus = { Rojo = 3, Amarillo = 3, Verde = 0, Azul = 0 }; s.dragon_mismo_color = true end, negativo = function(s) end },
    },
})

-- HERMES (Héroe)
beings.hermes = make_being({
    id = "hermes", nombre = "Hermes", tipo_hint = "heroe",
    descripcion = "Cartas rojas veloces, azules pierden daño",
    niveles = {
        [1] = { positivo = function(s) s.hermes_veloz = "Rojo" end, negativo = function(s) s.hermes_penaliza = { Azul = 0.5 } end },
        [2] = { positivo = function(s) s.hermes_veloz = "Rojo"; s.hermes_dano_extra = 1 end, negativo = function(s) s.hermes_penaliza = { Azul = 1 } end },
        [3] = { positivo = function(s) s.hermes_veloz = "Rojo"; s.hermes_dano_extra = 2 end, negativo = function(s) end },
    },
})

-- POSEIDÓN (Deidad)
beings.poseidon = make_being({
    id = "poseidon", nombre = "Poseidón", tipo_hint = "deidad",
    descripcion = "Azul aplica mojado, rojo penalizado",
    niveles = {
        [1] = { positivo = function(s) s.poseidon_mojado = true end, negativo = function(s) s.dano_rojo_penaliza = 1 end },
        [2] = { positivo = function(s) s.poseidon_mojado = true; s.poseidon_dano_mojado = 1 end, negativo = function(s) s.dano_rojo_penaliza = 2; s.poseidon_evapora = true end },
        [3] = { positivo = function(s) s.poseidon_mojado = true; s.poseidon_mult_azul = 2 end, negativo = function(s) end },
    },
})

-- HADES (Deidad)
beings.hades = make_being({
    id = "hades", nombre = "Hades", tipo_hint = "deidad",
    descripcion = "Cartas jugadas pueden volver al mazo, recibes descomposición",
    niveles = {
        [1] = { positivo = function(s) s.hades_recycle = 0.15 end, negativo = function(s) s.dano_descomposicion_entrante = 2 end },
        [2] = { positivo = function(s) s.hades_recycle = 0.25 end, negativo = function(s) s.dano_descomposicion_entrante = 4 end },
        [3] = { positivo = function(s) s.hades_recycle = 0.40 end, negativo = function(s) end },
    },
})

-- ARES (Héroe)
beings.ares = make_being({
    id = "ares", nombre = "Ares", tipo_hint = "heroe",
    descripcion = "Rojo +daño, Verde -daño",
    niveles = {
        [1] = { positivo = function(s) s.ares_bonus = { Rojo = 2, Verde = -1 } end, negativo = function(s) end },
        [2] = { positivo = function(s) s.ares_bonus = { Rojo = 3, Verde = -4 } end, negativo = function(s) end },
        [3] = { positivo = function(s) s.ares_bonus = { Rojo = 4, Verde = 0, Azul = 4, Amarillo = 4 } end, negativo = function(s) end },
    },
})

-- HEFESTO (Deidad)
beings.hefesto = make_being({
    id = "hefesto", nombre = "Hefesto", tipo_hint = "deidad",
    descripcion = "Probabilidad de mejorar carta al jugar",
    niveles = {
        [1] = { positivo = function(s) s.hefesto_mejora = { pct = 0.15, valor = 2 } end, negativo = function(s) s.hefesto_destruye = 0.10 end },
        [2] = { positivo = function(s) s.hefesto_mejora = { pct = 0.25, valor = 2 } end, negativo = function(s) s.hefesto_destruye = 0.30 end },
        [3] = { positivo = function(s) s.hefesto_mejora = { pct = 0.40, valor = 2 } end, negativo = function(s) end },
    },
})

-- ARTEMISA (Héroe)
beings.artemisa = make_being({
    id = "artemisa", nombre = "Artemisa", tipo_hint = "heroe",
    descripcion = "Verde +daño, Rojo -daño",
    niveles = {
        [1] = { positivo = function(s) s.artemisa_bonus = { Verde = 1, Rojo = -1 } end, negativo = function(s) end },
        [2] = { positivo = function(s) s.artemisa_bonus = { Verde = 2, Rojo = -999 } end, negativo = function(s) end },
        [3] = { positivo = function(s) s.artemisa_bonus = { Verde = 2 }; s.artemisa_veloz = true end, negativo = function(s) end },
    },
})

-- DIONISO (Deidad)
beings.dioniso = make_being({
    id = "dioniso", nombre = "Dioniso", tipo_hint = "deidad",
    descripcion = "Oro por escalera, daño por turno",
    niveles = {
        [1] = { positivo = function(s) s.dioniso_oro_escalera = 1 end, negativo = function(s) s.dano_por_turno = (s.dano_por_turno or 0) + 1 end },
        [2] = { positivo = function(s) s.dioniso_oro_escalera = 2 end, negativo = function(s) s.dano_por_turno = (s.dano_por_turno or 0) + 3 end },
        [3] = { positivo = function(s) s.dioniso_oro_escalera = 3; s.dioniso_comida_escalera = 1 end, negativo = function(s) end },
    },
})

-- GOLEM BARRO (Criatura)
beings.golem_barro = make_being({
    id = "golem_barro", nombre = "Golem de barro", tipo_hint = "criatura",
    descripcion = "+vida máxima, -daño",
    niveles = {
        [1] = { positivo = function(s) s.vida_max_pct = 1.10 end, negativo = function(s) s.dano_pct = 0.95 end },
        [2] = { positivo = function(s) s.vida_max_pct = 1.20 end, negativo = function(s) s.dano_pct = 0.90 end },
        [3] = { positivo = function(s) s.vida_max_pct = 1.40 end, negativo = function(s) end },
    },
})

-- HUMANO (Héroe)
beings.humano = make_being({
    id = "humano", nombre = "Humano", tipo_hint = "heroe",
    descripcion = "Penalización que luego se vuelve positiva",
    niveles = {
        [1] = { positivo = function(s) end, negativo = function(s) s.dano_recibido_extra = 2 end },
        [2] = { positivo = function(s) end, negativo = function(s) s.dano_recibido_extra = 3 end },
        [3] = { positivo = function(s) s.humano_dano_extra = 10 end, negativo = function(s) end },
    },
})

-- HIDRA (Criatura)
beings.hidra = make_being({
    id = "hidra", nombre = "Hidra", tipo_hint = "criatura",
    descripcion = "Trío regenera vida, escaleras cuestan oro",
    niveles = {
        [1] = { positivo = function(s) s.hidra_regenera_trio = 5 end, negativo = function(s) s.hidra_penaliza_escalera = 1 end },
        [2] = { positivo = function(s) s.hidra_regenera_trio = 10 end, negativo = function(s) s.hidra_dano_amarillo = 2 end },
        [3] = { positivo = function(s) s.hidra_regenera_trio = 15; s.hidra_dano_rival = 5 end, negativo = function(s) end },
    },
})

-- BASILISCO (Criatura)
beings.basilisco = make_being({
    id = "basilisco", nombre = "Basilisco", tipo_hint = "criatura",
    descripcion = "Verde aplica descomposición, recibes más daño de estados",
    niveles = {
        [1] = { positivo = function(s) s.basilisco_descomposicion = 1 end, negativo = function(s) s.dano_estados_extra = 1 end },
        [2] = { positivo = function(s) s.basilisco_descomposicion = 3 end, negativo = function(s) s.dano_estados_extra = 2 end },
        [3] = { positivo = function(s) s.basilisco_descomposicion = 5; s.basilisco_envenena = true end, negativo = function(s) end },
    },
})

-- AQUILES (Héroe)
beings.aquiles = make_being({
    id = "aquiles", nombre = "Aquiles", tipo_hint = "heroe",
    descripcion = "+daño primera carta, número aleatorio te daña",
    niveles = {
        [1] = { positivo = function(s) s.aquiles_primera = 3 end, negativo = function(s) s.aquiles_numero_maldito = { dano = 5 } end },
        [2] = { positivo = function(s) s.aquiles_primera = 5 end, negativo = function(s) s.aquiles_numero_maldito = { dano = 10 } end },
        [3] = { positivo = function(s) s.aquiles_primera = 8 end, negativo = function(s) end },
    },
})

-- ULISES (Héroe)
beings.ulises = make_being({
    id = "ulises", nombre = "Ulises", tipo_hint = "heroe",
    descripcion = "Rerolls gratis en tienda, pero pierdes oro",
    niveles = {
        [1] = { positivo = function(s) s.ulises_rerolls = 1 end, negativo = function(s) s.ulises_penalidad_oro = 1 end },
        [2] = { positivo = function(s) s.ulises_rerolls = 1 end, negativo = function(s) s.ulises_penalidad_oro = 3 end },
        [3] = { positivo = function(s) s.ulises_rerolls = 1; s.ulises_rebaja = true end, negativo = function(s) end },
    },
})

-- HÉRCULES (Héroe)
beings.hercules = make_being({
    id = "hercules", nombre = "Hércules", tipo_hint = "heroe",
    descripcion = "+daño por roja en mano, amarillo/verde anula",
    niveles = {
        [1] = { positivo = function(s) s.hercules_por_roja = 1 end, negativo = function(s) s.hercules_anula_amarillo = true end },
        [2] = { positivo = function(s) s.hercules_por_roja = 2 end, negativo = function(s) s.hercules_anula_verde = true; s.hercules_anula_amarillo = true end },
        [3] = { positivo = function(s) s.hercules_por_roja = 3 end, negativo = function(s) end },
    },
})

-- ATALANTA (Héroe)
beings.atalanta = make_being({
    id = "atalanta", nombre = "Atalanta", tipo_hint = "heroe",
    descripcion = "+daño por turno jugado, -tamaño mano",
    niveles = {
        [1] = { positivo = function(s) s.atalanta_dano_por_turno = 1 end, negativo = function(s) s.tamano_mano = (s.tamano_mano or 7) - 1 end },
        [2] = { positivo = function(s) s.atalanta_dano_por_turno = 2 end, negativo = function(s) s.tamano_mano = (s.tamano_mano or 7) - 2 end },
        [3] = { positivo = function(s) s.atalanta_dano_por_turno = 3 end, negativo = function(s) end },
    },
})

return beings
