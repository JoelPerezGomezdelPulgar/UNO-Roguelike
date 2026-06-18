local damage = {}

function damage.calcular_multiplicador(cartas)
    if #cartas == 0 then return 1 end
    local valores, colores = {}, {}
    for _, c in ipairs(cartas) do
        table.insert(valores, c.valor)
        table.insert(colores, c.color)
    end
    if #valores == 2 then
        if valores[1] == valores[2] then return 2 end
        return 1
    end
    if #valores == 3 then
        if colores[1] == colores[2] and colores[2] == colores[3] and
           valores[1] + 1 == valores[2] and valores[2] + 1 == valores[3] then
            return 5
        end
        if valores[1] == valores[2] and valores[2] == valores[3] and
           colores[1] == colores[2] and colores[2] == colores[3] then
            return 4
        end
        if valores[1] == valores[2] and valores[2] == valores[3] then return 3 end
        if valores[1] + 1 == valores[2] and valores[2] + 1 == valores[3] then return 3 end
    end
    return 1
end

function damage.calcular_dano(cartas, state)
    local suma = 0
    for _, c in ipairs(cartas) do
        local dmg = c.dano_base or c.valor
        -- Furia berserker/brebaje
        if state.furia_activa and state.furia_activa > 0 then
            dmg = dmg + state.furia_activa
        end
        -- Reliquias: on_card_damage
        for _, r in ipairs(state.relics or {}) do
            if r.on_card_damage then dmg = dmg + r.on_card_damage(c, state) end
        end
        -- Numero marcado
        if state.numero_marcado and c.valor == state.numero_marcado then dmg = dmg + 3 end
        -- Seres: bonificaciones por color
        if state.ares_bonus and state.ares_bonus[c.color] then
            dmg = dmg + state.ares_bonus[c.color]
        end
        if state.artemisa_bonus and state.artemisa_bonus[c.color] then
            dmg = dmg + state.artemisa_bonus[c.color]
        end
        if state.dragon_bonus and state.dragon_bonus[c.color] then
            dmg = dmg + state.dragon_bonus[c.color]
        end
        if state.hermes_penaliza and state.hermes_penaliza[c.color] then
            dmg = dmg - (dmg * state.hermes_penaliza[c.color])
        end
        if state.poseidon_dano_mojado and state.rival:has_status("mojado") then
            dmg = dmg + state.poseidon_dano_mojado
        end
        -- Puño avaricia
        if state.puno_avaricia then dmg = dmg + math.floor((state.oro or 0) / 4) end
        -- Aquiles: primera carta
        if state.aquiles_primera and cartas[1] == c then dmg = dmg + state.aquiles_primera end
        -- Atalanta: daño por turno
        if state.atalanta_dano_por_turno then dmg = dmg + state.atalanta_dano_por_turno * state.turno_actual end
        -- Hércules: por roja en mano
        if state.hercules_por_roja then
            local rojas = 0
            for _, mc in ipairs(state.jugador.mano) do if mc.color == "Rojo" then rojas = rojas + 1 end end
            dmg = dmg + state.hercules_por_roja * rojas
        end
        -- Daño eléctrico
        if c._electrico and state.dano_electrico_extra then dmg = dmg + state.dano_electrico_extra end
        suma = suma + math.max(0, dmg)
    end
    return suma
end

function damage.aplicar_estados(cartas, state)
    for _, c in ipairs(cartas) do
        if c.efectos then
            for _, ef in ipairs(c.efectos) do
                local efecto_def = require("cards.effects")[ef]
                if efecto_def and efecto_def.aplicar then
                    efecto_def.aplicar(c, state)
                end
            end
        end
        -- Poseidón: azul aplica mojado
        if state.poseidon_mojado and c.color == "Azul" then
            state.rival:aplicar_status("mojado", 3)
        end
        -- Basilisco: verde aplica descomposición
        if state.basilisco_descomposicion and c.color == "Verde" then
            state.rival:aplicar_status("descomposicion", state.basilisco_descomposicion)
        end
        if state.basilisco_envenena then
            state.rival:aplicar_status("veneno", 1)
        end
    end
end

function damage.calcular_mult_final(state, cartas)
    local mult = 1
    for _, r in ipairs(state.relics or {}) do
        if r.on_mult then mult = mult * r.on_mult(state) end
        if r.on_pre_mult then mult = mult * r.on_pre_mult(state) end
    end
    -- Minotauro
    if state.minotauro_dano_extra then mult = mult + state.minotauro_dano_extra * 0.1 end
    if state.mult_dano then mult = mult * state.mult_dano end
    -- Ojo de Ra
    mult = mult * (1 + (state.ojo_ra_mult or 0))
    -- Piedra imán
    for _, r in ipairs(state.relics or {}) do
        if r.on_post_mult then mult = mult * r.on_post_mult(state, cartas) end
    end
    -- Poseidón: mult azul si hay azul
    if state.poseidon_mult_azul then
        for _, c in ipairs(cartas) do
            if c.color == "Azul" then mult = mult * state.poseidon_mult_azul; break end
        end
    end
    return mult
end

function damage.procesar_cartas_jugadas(cartas, state)
    -- Aplicar efectos de carta individuales
    for _, c in ipairs(cartas) do
        if state.golpe_decisivo == 5 and cartas[1] == c then
            state.danoBase = state.danoBase + state.golpe_decisivo
            state.golpe_decisivo = nil
        end
        if c.efectos then
            for _, ef in ipairs(c.efectos) do
                local ef_def = require("cards.effects")[ef]
                if ef_def and ef_def.on_play then
                    local result = ef_def.on_play(c, state)
                    if result == "return_to_hand" then
                        table.insert(state.jugador.mano, c)
                    end
                end
            end
        end
    end

    -- Hermes: veloz
    if state.hermes_veloz then
        for _, c in ipairs(cartas) do
            if c.color == state.hermes_veloz then
                c.efectos = c.efectos or {}
                table.insert(c.efectos, "veloz")
            end
        end
    end
end

return damage
