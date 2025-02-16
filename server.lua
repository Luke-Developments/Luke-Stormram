RegisterNetEvent('luke-door:server:setState')
AddEventHandler('luke-door:server:setState', function(doorId, state)
    TriggerEvent('ox_doorlock:setState', doorId, state)
end)


RegisterNetEvent('luke-door:server:breachremove', function ()
    exports.ox_inventory:RemoveItem(source, 'handcuffs', 1)
end)
