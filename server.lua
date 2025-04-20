local QBCore = exports['qb-core']:GetCoreObject()

local Config = {
    notifySystem = 'okokNotify', -- Options: 'okokNotify', 'ox_lib', 'qb-notify', 'wasabi_notify', 'brutal_notify'
    gangItems = {'crowbar', 'lockpick'}, -- Items gangs can use to breach
    jobItems = {'breaching_tool', 'ram'}, -- Items jobs can use to breach
    tokenTimeout = 300, -- Token validity period in seconds
}

local activeTokens = {}

function SendNotify(src, message, type, duration)
    if Config.notifySystem == 'okokNotify' then
        TriggerClientEvent('okokNotify:Alert', src, 'Door Breach', message, duration, type, false)
    elseif Config.notifySystem == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Door Breach',
            description = message,
            type = type,
            duration = duration
        })
    elseif Config.notifySystem == 'qb-notify' then
        TriggerClientEvent('QBCore:Notify', src, message, type, duration)
    elseif Config.notifySystem == 'wasabi_notify' then
        TriggerClientEvent('wasabi_notify:Notify', src, {
            message = message,
            type = type,
            duration = duration
        })
    elseif Config.notifySystem == 'brutal_notify' then
        TriggerClientEvent('brutal_notify:SendAlert', src, 'Door Breach', message, duration, type)
    else
        print('Error: Invalid notification system configured')
    end
end

function ValidateToken(src, token, timestamp, doorId)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    
    local citizenId = player.PlayerData.citizenid
    local currentTime = os.time()
    
    local storedToken = activeTokens[token]
    if not storedToken then
        print(string.format("Invalid token: Not found for player %s", citizenId))
        return false
    end
    
    if storedToken.citizenId ~= citizenId or storedToken.doorId ~= doorId then
        print(string.format("Invalid token: Mismatch for player %s (expected door: %s, got: %s)", citizenId, storedToken.doorId, doorId))
        return false
    end
    
    if currentTime - timestamp > Config.tokenTimeout then
        print(string.format("Invalid token: Expired for player %s", citizenId))
        activeTokens[token] = nil 
        return false
    end
    
    return true
end

RegisterNetEvent('luke-door:server:registerToken', function(token, timestamp, doorId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    activeTokens[token] = {
        citizenId = citizenId,
        doorId = doorId,
        timestamp = timestamp
    }
end)

RegisterNetEvent('luke-door:server:setState', function(doorId, state, token, timestamp)
    local src = source
    if not ValidateToken(src, token, timestamp, doorId) then
        SendNotify(src, 'Invalid action detected', 'error', 3000)
        return
    end
    activeTokens[token] = nil 
    TriggerClientEvent('ox_doorlock:setState', -1, doorId, state)
end)

RegisterNetEvent('luke-door:server:breachremove', function(doorId, token, timestamp)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    if not ValidateToken(src, token, timestamp, doorId) then
        SendNotify(src, 'Invalid action detected', 'error', 3000)
        return
    end
    
    activeTokens[token] = nil 
    
    local removed = false
    for _, item in ipairs(Config.gangItems) do
        if exports.ox_inventory:RemoveItem(src, item, 1) then
            removed = true
            break
        end
    end
    if not removed then
        for _, item in ipairs(Config.jobItems) do
            if exports.ox_inventory:RemoveItem(src, item, 1) then
                removed = true
                break
            end
        end
    end
    if removed then
        SendNotify(src, 'Your breaching tool was damaged and removed', 'error', 3000)
    end
end)
