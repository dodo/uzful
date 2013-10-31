local awful = { tag = require('awful.tag') }
local capi = {
    client = client,
}

local client = {}
client.focus = {}

function client.focus.byabsidx(i, s)
    local tags = awful.tag.selectedlist(s)
    local clients
    for ti, t in ipairs(tags) do
        clients = t:clients()
        for ci, c in ipairs(clients) do
            if ti + ci - 2 == #clients - i then
                capi.client.focus = c
                return c
            end
        end
    end
end

return client
