local shop = {}

local shop_items = {
    poderes = function(state) return require("powers.registry") end,
    reliquias = function(state) return require("relics.registry") end,
    objetos = function(state) return require("items.registry") end,
}

function shop.generar_tienda(state)
    state.shop = {
        rerolls = 0,
        precio_reroll_base = 3,
        productos = {},
    }
    local pool = {}
    for _, v in pairs(require("relics.registry")) do
        if v.rareza ~= "legendario" then table.insert(pool, v) end
    end
    for _, v in pairs(require("items.registry")) do table.insert(pool, v) end
    for _, v in pairs(require("powers.registry")) do table.insert(pool, v) end

    -- 3 productos aleatorios
    for i = 1, 3 do
        if #pool > 0 then
            local idx = math.random(#pool)
            local item = pool[idx]
            local precio = item.precio_base or 5
            table.insert(state.shop.productos, { item = item, precio = precio })
        end
    end

    -- Ulises: rebaja
    if state.ulises_rebaja and math.random() < 0.5 then
        local idx = math.random(#state.shop.productos)
        state.shop.productos[idx].precio = math.floor(state.shop.productos[idx].precio / 2)
    end
end

function shop.comprar(state, idx)
    if not state.shop or not state.shop.productos[idx] then return false end
    local prod = state.shop.productos[idx]
    if (state.oro or 0) < prod.precio then return false end

    state.oro = state.oro - prod.precio
    local item = prod.item
    local tipo = determine_type(item)
    table.insert(state[tipo], item)
    table.remove(state.shop.productos, idx)

    -- Ulises: penalidad oro
    if state.ulises_penalidad_oro then
        state.oro = math.max(0, state.oro - state.ulises_penalidad_oro)
    end

    return true
end

function shop.reroll(state)
    if state.shop.ulises_reroll_usado then
        -- no more free rerolls
    end
    local costo = state.shop.precio_reroll_base + state.shop.rerolls * 1
    if (state.oro or 0) < costo then return false end
    state.oro = state.oro - costo
    state.shop.rerolls = state.shop.rerolls + 1
    shop.generar_tienda(state)
    return true
end

function shop.reroll_gratis(state)
    if state.ulises_rerolls and state.ulises_rerolls > 0 then
        state.ulises_rerolls = state.ulises_rerolls - 1
        shop.generar_tienda(state)
        return true
    end
    return false
end

function shop.generar_cuartel(state)
    local beings = require("beings.registry")
    local pool = {}
    for _, v in pairs(beings) do
        -- filter by available types; each boss unlock more
        if not state.shop.being_types_unlocked or state.shop.being_types_unlocked[v.tipo] then
            table.insert(pool, v)
        end
    end
    local disponibles = {}
    for i = 1, 3 do
        if #pool > 0 then
            local idx = math.random(#pool)
            table.insert(disponibles, pool[idx])
            table.remove(pool, idx)
        end
    end
    state.shop.cuartel = disponibles
end

function shop.seleccionar_ser(state, idx)
    if not state.shop.cuartel or not state.shop.cuartel[idx] then return false end
    local ser = state.shop.cuartel[idx]

    -- Check if same type exists (replace)
    for i, existing in ipairs(state.beings) do
        if existing.tipo == ser.tipo then
            table.remove(state.beings, i)
            break
        end
    end

    local nuevo_ser = { id = ser.id, nombre = ser.nombre, tipo = ser.tipo, nivel = 1 }
    table.insert(state.beings, nuevo_ser)

    -- Apply effects
    if ser.niveles[1] then
        if ser.niveles[1].positivo then ser.niveles[1].positivo(state) end
        if ser.niveles[1].negativo then ser.niveles[1].negativo(state) end
    end

    state.shop.cuartel = nil
    return true
end

function shop.generar_mercader(state)
    local tipos_cofre = {"objetos", "cartas", "reliquias"}
    local tipo = tipos_cofre[math.random(#tipos_cofre)]
    local precio = 3 + math.random(3)
    state.shop.mercader = {
        tipo = tipo,
        precio = precio,
        items = {},
    }
    local pool = {}
    if tipo == "objetos" then
        for _, v in pairs(require("items.registry")) do table.insert(pool, v) end
    elseif tipo == "reliquias" then
        for _, v in pairs(require("relics.registry")) do
            if v.rareza ~= "legendario" then table.insert(pool, v) end
        end
    elseif tipo == "cartas" then
        -- random card
        for _, v in pairs(require("data.cards")) do table.insert(pool, v) end
    end
    for i = 1, 3 do
        if #pool > 0 then
            local idx = math.random(#pool)
            table.insert(state.shop.mercader.items, pool[idx])
            table.remove(pool, idx)
        end
    end
end

function shop.comprar_cofre(state)
    if not state.shop.mercader then return false end
    if (state.oro or 0) < state.shop.mercader.precio then return false end
    state.oro = state.oro - state.shop.mercader.precio
    for _, item in ipairs(state.shop.mercader.items) do
        table.insert(state[state.shop.mercader.tipo], item)
    end
    state.shop.mercader = nil
    return true
end

function determine_type(item)
    if item.cooldown then return "poderes"
    elseif item.usar then return "objetos"
    else return "relics" end
end

return shop
