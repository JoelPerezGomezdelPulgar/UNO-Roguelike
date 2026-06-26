-- Card status effects (applied when played)
-- Functions receive (card, state) and modify state

local card_effects = {}

card_effects.quemado = {
    aplicar = function(card, state)
        state.rival:aplicar_estados("quemado", 3)
    end,
}

card_effects.mojado = {
    aplicar = function(card, state)
        state.rival:aplicar_estados("mojado", 3)
    end,
}

card_effects.veneno = {
    aplicar = function(card, state)
        state.rival:aplicar_estados("veneno", 2)
    end,
}

card_effects.descomposicion = {
    aplicar = function(card, state)
        state.rival:aplicar_estados("descomposicion", 3)
    end,
}

card_effects.veloz = {
    aplicar = function(card, state)
        state.veloz_activo = (state.veloz_activo or 0) + 2
    end,
}

card_effects.temporal = {
    on_combat_end = function(card, state)
        -- carta se destruye
        return "destroy"
    end,
}

card_effects.repetitivo = {
    on_play = function(card, state)
        if not card._repetido then
            card._repetido = true
            return "return_to_hand"
        end
    end,
}

card_effects.incesante = {
    on_play = function(card, state)
        return "return_to_hand"
    end,
}

card_effects.fantasmal = {
    -- no ocupa espacio - handled in hand.lua
}

card_effects.electrico = {
    aplicar = function(card, state)
        local extra = state.dano_electrico_extra or 0
        return extra
    end,
}

card_effects.descompuesta = {
    aplicar = function(card, state)
        state.rival:aplicar_estados("descomposicion", 4)
    end,
}

return card_effects
