local colors = require("data.colors")

local card_defs = {}
local id = 0
for color_name, _ in pairs(colors) do
    id = id + 1
    card_defs[id] = {
        id = id,
        valor = 0,
        color = color_name,
        dano_base = 0,
    }
    for valor = 1, 9 do
        id = id + 1
        card_defs[id] = {
            id = id,
            valor = valor,
            color = color_name,
            dano_base = valor,
        }
        id = id + 1
        card_defs[id] = {
            id = id,
            valor = valor,
            color = color_name,
            dano_base = valor,
        }
    end
end

return card_defs
