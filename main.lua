if not table.unpack then table.unpack = rawget(_G, "unpack") end

local COLORES = require("datos.colors")
local juego = require("juego")
local mundo = require("mundo")
local combate = require("combate.init")
local tienda = require("tienda")

local state
local selected = {}
local mensaje = ""
local mensaje_timer = 0
local accion_pendiente = nil
local mostrar_mano_rival = false
local sel_inicio = 0
local sel_arrastrando = false
local sel_ultimo_idx = nil

-- UI constants
local CARTA_W, CARTA_H = 80, 120
local CARTA_ESPACIO = 10

local BASE_W, BASE_H = 1000, 700
local s, ox, oy = 1, 0, 0

local danoBase = 0
local danoMulti = 1

function love.load()
    math.randomseed(os.time())
    local w, h = love.graphics.getDimensions()
    s = math.min(w / BASE_W, h / BASE_H)
    ox = (w - BASE_W * s) / 2
    oy = (h - BASE_H * s) / 2
    state = juego.nuevo_juego()
    state.fase = "menu"
end

function love.resize(w, h)
    s = math.min(w / BASE_W, h / BASE_H)
    ox = (w - BASE_W * s) / 2
    oy = (h - BASE_H * s) / 2
end

function dibujar_carta(x, y, carta, seleccionada, oculta, w, h)
    w = w or CARTA_W
    h = h or CARTA_H
    if oculta then
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", x + 5, y + 5, w - 10, h - 10, 4, 4)
        return
    end

    local c = COLORES[carta.color] or { r = 0.8, g = 0.8, b = 0.8 }
    if seleccionada then
        love.graphics.setLineWidth(4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x - 4, y - 4, w + 8, h + 8)
    end

    love.graphics.setColor(c.r, c.g, c.b, 0.9)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    if carta.efectos then
        for _, ef in ipairs(carta.efectos) do
            if ef == "descompuesta" then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.2)
                love.graphics.rectangle("fill", x, y, w, h, 6, 6)
                break
            end
        end
    end

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", x, y, w, 22, 6, 6)

    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local vs = tostring(carta.valor)
    love.graphics.print(vs, x + w / 2 - font:getWidth(vs) / 2, y + 3)

    if carta.efectos then
        love.graphics.setColor(1, 1, 0.3)
        love.graphics.print(table.concat(carta.efectos, ","), x + 2, y + h - 30, w - 4)
        love.graphics.setColor(1, 1, 1)
    end
end

function dibujar_barra_vida(x, y, w, hp, max_hp, nombre)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(nombre, x, y - 18)
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", x, y, w, 22)
    local ratio = math.max(0, hp / max_hp)
    love.graphics.setColor(1 - ratio, ratio, 0)
    love.graphics.rectangle("fill", x, y, w * ratio, 22)
    love.graphics.setColor(1, 1, 1)
    local hp_str = math.max(0, math.floor(hp)) .. "/" .. max_hp
    love.graphics.print(hp_str, x + w / 2 - love.graphics.getFont():getWidth(hp_str) / 2, y + 4)
end

function dibujar_boton(x, y, w, h, texto, enabled)
    love.graphics.setColor(enabled and 0.3 or 0.2, enabled and 0.6 or 0.2, enabled and 0.3 or 0.2, enabled and 1 or 0.5)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(1, 1, 1, enabled and 1 or 0.5)
    local tw = love.graphics.getFont():getWidth(texto)
    love.graphics.print(texto, x + w / 2 - tw / 2, y + h / 2 - 8)
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(s, s)

    if state.fase == "menu" then
        love.graphics.setBackgroundColor(0.08, 0.08, 0.12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("UNO Roguelike", 0, 200, 1000, "center")
        love.graphics.printf("Presiona ESPACIO para empezar", 0, 300, 1000, "center")
        love.graphics.pop()
        return
    end

    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    if state.fase == "combat" then
        dibujar_combate()
    elseif state.fase == "tienda" then
        dibujar_tienda()
    elseif state.fase == "game_over" then
        dibujar_game_over()
    end

    -- Mensaje global
    if mensaje_timer > 0 then
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.printf(mensaje, 100, 300, 800, "center")
    end

    love.graphics.pop()
end

function dibujar_combate()
    if not state.rival or not state.jugador then return end

    if state.mostrando_mazo then
        dibujar_visor_mazo()
        return
    end

    -- HP bars
    dibujar_barra_vida(20, 30, 350, state.jugador.vida, state.jugador.vida_max, "Alice (Tú)")
    dibujar_barra_vida(630, 30, 350, state.rival.vida, state.rival.vida_max, state.rival.nombre)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Mundo " .. (state.mundo_actual or 1) .. " - Nivel " .. (state.nivel_actual or 1), 400, 10)

    -- Panel de poderes a la izquierda
    dibujar_panel_poderes()

    -- Mano rival (oculta o visible)
    love.graphics.print("Mano rival:", 630, 140)
    local rx, ry = 630, 160
    for i, c in ipairs(state.rival.mano) do
        local mostrar = mostrar_mano_rival or state.ver_mano_rival
        dibujar_carta(rx + (i - 1) * 55, ry, c, false, not mostrar)
        if i > 7 then break end
    end

    -- Carta en mesa
    local top = state.mesa and state.mesa[#state.mesa]
    if top then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Mesa:", 450, 90)
        dibujar_carta(460, 110, top, false, false)
    end

    -- Mazo clickeable
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Mazo:", 450, 240)
    dibujar_carta(460, 260, nil, false, true)
    love.graphics.setColor(1, 1, 1)
    local mazo_count = #state.mazo_jugador
    local mc_str = tostring(mazo_count) .. " cartas"
    love.graphics.print(mc_str, 460 + CARTA_W / 2 - love.graphics.getFont():getWidth(mc_str) / 2, 260 + CARTA_H / 2 - 8)

    -- Mano del jugador
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tu mano:", 20, 440)

    local sx = 20
    local sy = 460
    for i, carta in ipairs(state.jugador.mano) do
        local sel = false
        for _, si in ipairs(selected) do
            if si == i then
                sel = true; break
            end
        end
        dibujar_carta(sx + (i - 1) * (CARTA_W + CARTA_ESPACIO), sy, carta, sel, false)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(tostring(i), sx + (i - 1) * (CARTA_W + CARTA_ESPACIO) + 2, sy + CARTA_H - 14)
    end

    -- Botones
    local bx, by = 880, 460
    dibujar_boton(bx, by, 100, 30, "Jugar", #selected > 0)
    dibujar_boton(bx, by + 40, 100, 30, "Robar", true)
    dibujar_boton(bx, by + 80, 100, 30, "Poderes", #state.poderes > 0)
    dibujar_boton(bx, by + 120, 100, 30, "Objetos", #state.objetos > 0)

    if state.aturdido and state.aturdido > 0 then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.print("ATURDIDO (" .. state.aturdido .. " turno(s))", 400, 300)
        love.graphics.setColor(1, 1, 1)
        dibujar_boton(bx, by + 160, 100, 30, "Saltar turno", true)
    end

    -- Ver mano rival toggle
    if state.ver_mano_rival then mostrar_mano_rival = true end

    -- Panel de reliquias
    dibujar_panel_reliquias()

    -- Oro y comida (dibujados después del panel de reliquias)
    love.graphics.setColor(1, 1, 1)
    local descomp_cargas = state.rival.status and state.rival.status.descomposicion or 0
    local descomp_texto = ""
    if descomp_cargas > 0 then
        descomp_texto = "  |  Descomposición: " .. descomp_cargas
    end
    love.graphics.print("Oro: " .. (state.oro or 0) .. "  |  Comida: " .. (state.comida or 0) .. descomp_texto, 20, 55)
end

function dibujar_panel_reliquias()
    if not state.reliquias or #state.reliquias == 0 then return end

    local px = state.reliquias_panel_x
    local py = state.reliquias_panel_y
    local pw = state.reliquias_panel_w
    local psh = 165
    local psw = state.reliquias_hueco_w
    local offset = state.reliquias_offset or 0

    -- Fondo del panel
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", px, py, pw, psh, 4, 4)
    love.graphics.setColor(0.6, 0.6, 0.9)
    love.graphics.print("Reliquias", px + 4, py + 2)

    -- Clip al area del panel
    love.graphics.push()
    love.graphics.setScissor(px, py, pw, psh)

    for i, r in ipairs(state.reliquias) do
        local rx = px + (i - 1) * psw - offset
        if rx + psw > px and rx < px + pw then
            local rb = r.id and require("reliquias.registry")[r.id] or r

            -- Slot de reliquia
            love.graphics.setColor(0.25, 0.2, 0.3)
            love.graphics.rectangle("fill", rx + 2, py + 2, psw - 4, psh - 4, 4, 4)

            -- Borde si es la primera (activa)
            if i == 1 then
                love.graphics.setLineWidth(2)
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.rectangle("line", rx + 2, py + 2, psw - 4, psh - 4, 4, 4)
                love.graphics.setLineWidth(1)
            end

            -- Nombre (truncado)
            love.graphics.setColor(1, 1, 1)
            local nombre = (rb.nombre or r.id or "?")
            love.graphics.printf(nombre, rx + 4, py + 8, psw - 8, "left")

            -- Descripcion corta
            love.graphics.setColor(0.7, 0.7, 0.7)
            local desc = (rb.descripcion or "")
            if #desc > 30 then desc = desc:sub(1, 27) .. "..." end
            love.graphics.printf(desc, rx + 4, py + 28, psw - 8, "left")

            -- Indice
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(tostring(i), rx + psw - 16, py + 2)
        end
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function dibujar_tienda()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("TIENDA", 0, 20, 1000, "center")
    love.graphics.print("Oro: " .. (state.oro or 0), 20, 50)

    if not state.shop then tienda.generar_tienda(state) end

    -- Productos
    local px, py = 100, 100
    for i, prod in ipairs(state.shop.productos or {}) do
        local item = prod.item
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", px, py, 250, 60, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print((i) .. ". " .. (item.nombre or item.id), px + 10, py + 5)
        love.graphics.print((item.descripcion or ""), px + 10, py + 25)
        love.graphics.print("Precio: " .. prod.precio, px + 10, py + 43)
        love.graphics.setColor(0.3, 0.7, 0.3)
        love.graphics.rectangle("fill", px + 190, py + 40, 50, 20, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Comprar", px + 195, py + 43)
        py = py + 70
    end

    dibujar_boton(800, 100, 120, 30, "Reroll (" .. state.shop.precio_reroll_base + (state.shop.rerolls or 0) * 1 .. " oro)",
        true)
    dibujar_boton(800, 140, 120, 30, "Siguiente", true)

    if state.shop.cuartel then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("CUARTEL", 100, 400)
        local cy = 430
        for i, ser in ipairs(state.shop.cuartel) do
            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", 100, cy, 400, 40, 4, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(i .. ". " .. ser.nombre .. " (" .. ser.tipo .. "): " .. (ser.descripcion or ""), 110,
                cy + 5)
            cy = cy + 45
        end
    end

    if state.shop.mercader then
        local m = state.shop.mercader
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("MERCADER: Cofre de " .. m.tipo .. " (" .. m.precio .. " oro)", 100, 550)
        dibujar_boton(400, 550, 100, 30, "Comprar", (state.oro or 0) >= m.precio)
    end
end

function dibujar_game_over()
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.printf("GAME OVER", 0, 250, 1000, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Mundo " .. (state.mundo_actual or 1) .. " - Nivel " .. (state.nivel_actual or 1), 0, 300, 1000,
        "center")
    love.graphics.printf("Presiona ESPACIO para reiniciar", 0, 350, 1000, "center")
end

function dibujar_panel_poderes()
    local defs = require("poderes.registry")
    local px, py = 20, 120
    local pw, ph = 210, 50
    local bth = 24

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PODERES", px, py - 18)

    for i, p in ipairs(state.poderes) do
        local d = defs[p.id]
        local listo = not p.cooldown_actual or p.cooldown_actual <= 0
        local color = listo and { 0.2, 0.35, 0.2 } or { 0.3, 0.2, 0.2 }

        -- Fondo del poder
        love.graphics.setColor(color[1], color[2], color[3], 0.85)
        love.graphics.rectangle("fill", px, py, pw, ph, 4, 4)

        -- Nombre
        love.graphics.setColor(listo and 1 or 0.6, listo and 1 or 0.6, listo and 1 or 0.6)
        love.graphics.print((d and d.nombre or p.id) .. (listo and "" or " [CD:" .. p.cooldown_actual .. "]"), px + 4,
            py + 2)

        -- Descripcion (truncada)
        local desc = (d and d.descripcion or "")
        if #desc > 50 then desc = desc:sub(1, 47) .. "..." end
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(desc, px + 4, py + 18, pw - 8, "left")

        -- Boton activar
        local bx = px + pw / 2 - 40
        local by = py + ph + 2
        love.graphics.setColor(listo and 0.2 or 0.15, listo and 0.5 or 0.15, listo and 0.2 or 0.15)
        love.graphics.rectangle("fill", bx, by, 80, bth, 3, 3)
        love.graphics.setColor(listo and 1 or 0.4, listo and 1 or 0.4, listo and 1 or 0.4)
        love.graphics.print("Activar", bx + 20, by + 4)

        py = py + ph + bth + 6
    end
    state._poderes_panel_y = { px = px, py_start = 120, pw = pw, ph = ph, bth = bth }
end

function dibujar_visor_mazo()
    love.graphics.setColor(0, 0, 0, 0.87)
    love.graphics.rectangle("fill", 0, 0, 1000, 700)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("MAZO - Click para cerrar", 0, 8, 1000, "center")

    local armor = {}
    for _, c in ipairs(state.jugador.mano or {}) do armor[c] = "mano" end
    for _, c in ipairs(state.mesa or {}) do armor[c] = "mesa" end

    local color_order = { "Rojo", "Amarillo", "Azul", "Verde" }
    local cw, ch = 60, 90
    local overlap = 35
    local start_x = 20
    local row_y = 45
    local row_h = ch + 18

    for _, color_name in ipairs(color_order) do
        local band = {}
        for _, c in ipairs(state.mazo_jugador or {}) do
            if c.color == color_name then table.insert(band, { card = c, loc = "mazo" }) end
        end
        for _, c in ipairs(state.jugador.mano or {}) do
            if c.color == color_name then table.insert(band, { card = c, loc = "mano" }) end
        end
        for _, c in ipairs(state.mesa or {}) do
            if c.es_jugador and c.color == color_name then table.insert(band, { card = c, loc = "mesa" }) end
        end
        table.sort(band, function(a, b)
            if a.card.valor ~= b.card.valor then return a.card.valor < b.card.valor end
            return a.card.id < b.card.id
        end)

        -- header
        love.graphics.setColor(1, 1, 1)
        local hdr = color_name .. " (" .. #band .. ")"
        love.graphics.print(hdr, start_x, row_y)

        -- cards
        for i, entry in ipairs(band) do
            local x = start_x + (i - 1) * overlap
            local y = row_y + 16
            local en_mazo = entry.loc == "mazo"
            dibujar_carta(x, y, entry.card, false, false, cw, ch)

            if not en_mazo then
                love.graphics.setColor(0, 0, 0, 0.55)
                love.graphics.rectangle("fill", x, y, cw, ch, 6, 6)
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print(entry.loc, x + 2, y + ch - 14)
            end
        end

        row_y = row_y + row_h
    end
end

function love.mousepressed(mx, my, button)
    mx, my = (mx - ox) / s, (my - oy) / s

    if state.fase == "combat" then
        if button == 1 then
            manejar_click_combate(mx, my)
        elseif button == 2 then
            manejar_click_derecho_combate(mx, my)
        end
    elseif state.fase == "tienda" then
        manejar_click_tienda(mx, my)
    end
end

function love.mousemoved(mx, my)
    if sel_arrastrando then
        mx, my = (mx - ox) / s, (my - oy) / s
        local sx, sy = 20, 460
        local hover = nil
        for i, _ in ipairs(state.jugador.mano) do
            local cx = sx + (i - 1) * (CARTA_W + CARTA_ESPACIO)
            if mx >= cx and mx <= cx + CARTA_W and my >= sy and my <= sy + CARTA_H then
                hover = i; break
            end
        end
        if hover and hover ~= sel_ultimo_idx then
            sel_ultimo_idx = hover
            local inicio = math.min(sel_inicio, hover)
            local fin = math.max(sel_inicio, hover)
            local seleccionando = true
            for _, si in ipairs(selected) do
                if si == sel_inicio then seleccionando = false; break end
            end
            selected = {}
            if seleccionando then
                for j = inicio, fin do
                    if #selected < 3 then table.insert(selected, j) end
                end
            end
        end
        if not hover then sel_ultimo_idx = nil end
        return
    end
    if not state.arrastrando_reliquia then return end
    mx = (mx - ox) / s
    local px = state.reliquias_panel_x
    local psw = state.reliquias_hueco_w
    local offset = state.reliquias_offset or 0
    local target_idx = math.floor((mx - px + offset) / psw) + 1
    if target_idx >= 1 and target_idx <= #state.reliquias and target_idx ~= state.arrastrando_reliquia then
        local r = table.remove(state.reliquias, state.arrastrando_reliquia)
        table.insert(state.reliquias, target_idx, r)
        state.arrastrando_reliquia = target_idx
    end
end

function love.mousereleased(mx, my, button)
    if button == 1 then
        state.arrastrando_reliquia = nil
    elseif button == 2 then
        sel_arrastrando = false
        sel_inicio = 0
        sel_ultimo_idx = nil
    end
end

function love.wheelmoved(x, y)
    if state.fase ~= "combat" then return end
    local px = state.reliquias_panel_x
    local py = state.reliquias_panel_y
    local pw = state.reliquias_panel_w
    local psw = state.reliquias_hueco_w
    local max_offset = math.max(0, #(state.reliquias or {}) * psw - pw)
    state.reliquias_offset = math.max(0, math.min(max_offset, (state.reliquias_offset or 0) - y * 50))
end

function manejar_click_derecho_combate(mx, my)
    local sx, sy = 20, 460
    for i, _ in ipairs(state.jugador.mano) do
        local cx = sx + (i - 1) * (CARTA_W + CARTA_ESPACIO)
        if mx >= cx and mx <= cx + CARTA_W and my >= sy and my <= sy + CARTA_H then
            sel_inicio = i
            sel_arrastrando = true
            return
        end
    end
end

function manejar_click_combate(mx, my)
    if state.mostrando_mazo then
        state.mostrando_mazo = false
        return
    end

    -- Click en mazo
    local deck_x, deck_y = 460, 260
    if mx >= deck_x and mx <= deck_x + CARTA_W and my >= deck_y and my <= deck_y + CARTA_H then
        state.mostrando_mazo = true
        accion_pendiente = nil
        return
    end

    -- Card clicks in player hand
    local sx, sy = 20, 460
    for i, _ in ipairs(state.jugador.mano) do
        local cx = sx + (i - 1) * (CARTA_W + CARTA_ESPACIO)
        local cy = sy
        if mx >= cx and mx <= cx + CARTA_W and my >= cy and my <= cy + CARTA_H then
            -- Pending power target selection
            if accion_pendiente then
                local carta = state.jugador.mano[i]
                local ap = accion_pendiente
                accion_pendiente = nil
                if ap.type == "marcaje" then
                    local resultado = juego.usar_poder(state, ap.idx, carta.valor)
                    mensaje = resultado and resultado.mensaje or ""
                    mensaje_timer = 180
                end
                return
            end
            local found = nil
            for idx, si in ipairs(selected) do
                if si == i then
                    found = idx; break
                end
            end
            if found then
                table.remove(selected, found)
            elseif #selected < 3 then
                table.insert(selected, i)
            end
            return
        end
    end

    -- Not a card click => clear any pending power target selection
    accion_pendiente = nil

    -- Power buttons (izquierda)
    local ppw, pph, pbth = 210, 50, 24
    local ppy = 120
    for i, p in ipairs(state.poderes) do
        local listo = not p.cooldown_actual or p.cooldown_actual <= 0
        local pbx = 20 + ppw / 2 - 40
        local pby = ppy + pph + 2
        if mx >= pbx and mx <= pbx + 80 and my >= pby and my <= pby + pbth and listo then
            if p.id == "marcaje" then
                accion_pendiente = { type = "marcaje", idx = i }
                mensaje = "Selecciona una carta de tu mano para marcar su número"
                mensaje_timer = 180
                return
            end
            local resultado = juego.usar_poder(state, i)
            mensaje = resultado and resultado.mensaje or ""
            mensaje_timer = 180
            return
        end
        ppy = ppy + pph + pbth + 6
    end

    -- Buttons
    local bx, by = 880, 460
    if mx >= bx and mx <= bx + 100 and my >= by and my <= by + 30 and #selected > 0 then
        local resultado = juego.turno_jugador(state, "jugar", { indices = selected })
        mensaje = resultado and resultado.mensaje or ""
        mensaje_timer = 180
        selected = {}
        if state.fase == "tienda" then
            tienda.generar_tienda(state)
        end
    end
    if mx >= bx and mx <= bx + 100 and my >= by + 40 and my <= by + 70 then
        local resultado = juego.turno_jugador(state, "robar")
        mensaje = resultado and resultado.mensaje or ""
        mensaje_timer = 120
        selected = {}
        if state.fase == "tienda" then
            tienda.generar_tienda(state)
        end
    end
    if mx >= bx and mx <= bx + 100 and my >= by + 80 and my <= by + 110 then
        if #state.poderes > 0 then
            local defs = require("poderes.registry")
            local txt = "Poderes:\n"
            for i, p in ipairs(state.poderes) do
                local d = defs[p.id]
                txt = txt ..
                    i ..
                    ". " ..
                    (d and d.nombre or p.id) ..
                    (p.cooldown_actual and p.cooldown_actual > 0 and " [CD:" .. p.cooldown_actual .. "]" or " [LISTO]") ..
                    "\n"
            end
            love.system.setClipboardText(txt) -- quick hack
            mensaje = "Poderes copiados al portapapeles. Usa 1-9 para activar"
            mensaje_timer = 180
        end
    end
    if mx >= bx and mx <= bx + 100 and my >= by + 120 and my <= by + 150 then
        if #state.objetos > 0 then
            local defs = require("objetos.registry")
            local txt = "Objetos:\n"
            for i, o in ipairs(state.objetos) do
                local d = defs[o.id]
                txt = txt .. i .. ". " .. (d and d.nombre or o.id) .. "\n"
            end
            love.system.setClipboardText(txt)
            mensaje = "Objetos copiados al portapapeles. Usa 0 para abrir inventario"
            mensaje_timer = 180
        end
    end
    -- Saltar turno (aturdido)
    if state.aturdido and state.aturdido > 0 then
        if mx >= bx and mx <= bx + 100 and my >= by + 160 and my <= by + 190 then
            local resultado = juego.turno_jugador(state, "saltar")
            mensaje = resultado and resultado.mensaje or ""
            mensaje_timer = 120
            selected = {}
        end
    end
    -- Click en panel de reliquias (drag & drop)
    if state.reliquias and #state.reliquias > 0 then
        local px = state.reliquias_panel_x
        local py = state.reliquias_panel_y
        local pw = state.reliquias_panel_w
        local psh = 165
        if mx >= px and mx <= px + pw and my >= py and my <= py + psh then
            local offset = state.reliquias_offset or 0
            local idx = math.floor((mx - px + offset) / state.reliquias_hueco_w) + 1
            if idx >= 1 and idx <= #state.reliquias then
                state.arrastrando_reliquia = idx
                state.arrastrar_inicio_x = mx
            end
        end
    end
end

function manejar_click_tienda(mx, my)
    -- Comprar productos
    local px, py = 100, 100
    for i, prod in ipairs(state.shop.productos or {}) do
        if mx >= px + 190 and mx <= px + 240 and my >= py + 40 and my <= py + 60 then
            if juego.comprar_tienda(state, i) then
                mensaje = "Comprado!"
                mensaje_timer = 120
            else
                mensaje = "No tienes suficiente oro"
                mensaje_timer = 120
            end
        end
        py = py + 70
    end

    -- Reroll
    if mx >= 800 and mx <= 920 and my >= 100 and my <= 130 then
        if juego.reroll_tienda(state) then
            mensaje = "Reroll"
            mensaje_timer = 60
        else
            mensaje = "No tienes suficiente oro"
            mensaje_timer = 120
        end
    end

    -- Siguiente
    if mx >= 800 and mx <= 920 and my >= 140 and my <= 170 then
        local resultado = mundo.avanzar_nivel(state)
        if resultado == "combat" then
            combate.iniciar(state)
            state.fase = "combat"
        elseif resultado == "bonus" then
            state.fase = "bonus"
        elseif resultado == "boss" then
            combate.iniciar(state)
            state.fase = "combat"
        end
        selected = {}
    end

    -- Mercader
    if state.shop.mercader and mx >= 400 and mx <= 500 and my >= 550 and my <= 580 then
        if tienda.comprar_cofre(state) then
            mensaje = "Cofre comprado!"
            mensaje_timer = 120
        else
            mensaje = "No tienes suficiente oro"
            mensaje_timer = 120
        end
    end
end

function love.keypressed(key)
    if state.fase == "menu" and key == "space" then
        juego.iniciar_partida(state)
        return
    end

    if state.fase == "game_over" and key == "space" then
        state = juego.nuevo_juego()
        state.fase = "menu"
        return
    end

    if state.fase == "combat" then
        if key == "escape" then
            state.mostrando_mazo = false
        end
        if key == "v" then
            mostrar_mano_rival = not mostrar_mano_rival
        end
        if key == "d" then
            local resultado = juego.turno_jugador(state, "robar")
            mensaje = resultado and resultado.mensaje or ""
            mensaje_timer = 120
            selected = {}
        end
        if key == "p" then
            if state.jugador.status and state.jugador.status.veneno then
                state.jugador.status.veneno = nil
                mensaje = "Antídoto funcionó! Veneno eliminado."
                mensaje_timer = 180
            else
                state.jugador:aplicar_estados("veneno", 5)
                mensaje = "Te infligiste Veneno x5"
                mensaje_timer = 180
            end
        end
    end

    if key:find("f") then
        local n = tonumber(key:sub(2))
        if n and state.fase == "combat" then
            local shift = love.keyboard.isDown("lshift", "rshift")
            local ctrl = love.keyboard.isDown("lctrl", "rctrl")
            local idx = n
            if ctrl then
                idx = 24 + n
            elseif shift then
                idx = 12 + n
            end
            local relic_ids = {
                [1] = "ojo_ra",
                [2] = "caliz_elementos",
                [3] = "cornucopia",
                [4] = "pergamino_leyendas",
                [5] = "puno_avaricia",
                [6] = "blason_elemental",
                [7] = "escudo_eter",
                [8] = "colgante_ambar",
                [9] = "anillo_vacio",
                [10] = "contrato_maldito",
                [11] = "gema_caos",
                [12] = "concha_triton",
                [13] = "ojo_ra",
                [14] = "caliz_elementos",
                [15] = "puno_avaricia",
                [16] = "blason_elemental",
                [17] = "escudo_eter",
                [18] = "anillo_vacio",
                [19] = "contrato_maldito",
                [20] = "gema_caos",
                [21] = "guantes_seda",
                [22] = "amuleto_eco",
                [23] = "lente_aumento",
                [24] = "piedra_iman",
                [25] = "carta_marcada",
                [26] = "sello_sangre",
                [27] = "bolsa_arena",
                [28] = "colmillo_plata",
                [29] = "pendulo_lunar",
                [30] = "ala_cuervo",
                [31] = "espejo_reflector",
            }
            local id = relic_ids[idx]
            if id then
                local relic_def = require("reliquias.registry")[id]
                if relic_def then
                    table.insert(state.reliquias, relic_def)
                    mensaje = "DEBUG: Reliquia '" .. (relic_def.nombre or id) .. "' añadida (F" .. n .. (shift and " Shift" or ctrl and " Ctrl" or "") .. ")"
                    mensaje_timer = 180
                end
            end
        end
    end
end

function love.update(dt)
    if mensaje_timer > 0 then mensaje_timer = mensaje_timer - 1 end

    if state.fase == "combat" then
        if state.jugador.vida <= 0 then
            local res = mundo.procesar_derrota(state)
            if res == "game_over" then
                state.fase = "game_over"
                mensaje = "Game Over"
                mensaje_timer = 9999
            end
        end
        if state.rival and state.rival.vida <= 0 then
            mundo.procesar_victoria(state)
            state.fase = "tienda"
            tienda.generar_tienda(state)
            mensaje = "Victoria!"
            mensaje_timer = 180
        end
    end

end
