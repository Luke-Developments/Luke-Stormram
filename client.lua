local QBCore = exports['qb-core']:GetCoreObject()

-- Configuration
local Config = {
    allowedGangs = {'lostmc', 'ballas', 'triads'}, -- Gangs allowed to breach
    allowedJobs = {'police', 'sheriff'}, -- Jobs allowed to breach
    gangItems = {'crowbar', 'lockpick'}, -- Items gangs can use to breach
    jobItems = {'police_stormram', 'ram'}, -- Items jobs can use to breach
    useSpecificDoors = true, -- Toggle: true = only specific doors, false = all doors
    specificDoors = {'door1', 'door2', 'vault_door'}, -- Specific door names (used if useSpecificDoors = true)
    useSkillCheck = true, -- Toggle skill check (Thermite and Circle minigames)
    breachCooldown = 300000, -- Cooldown per player in milliseconds (5 minutes)
    notifySystem = 'okok', -- Options: 'okok', 'ox', 'qb', 'wasabi', 'brutal'
    inventorySystem = 'ox', -- Options: 'ox', 'qb', 'qs', 'lj'
}

local lastBreachTime = 0

function SendNotify(message, type, duration)
    if Config.notifySystem == 'okok' then
        exports['okokNotify']:Alert('Door Breach', message, duration, type, false)
    elseif Config.notifySystem == 'ox' then
        lib.notify({
            title = 'Door Breach',
            description = message,
            type = type,
            duration = duration
        })
    elseif Config.notifySystem == 'qb' then
        QBCore.Functions.Notify(message, type, duration)
    elseif Config.notifySystem == 'wasabi' then
        exports['wasabi_notify']:Notify({
            message = message,
            type = type,
            duration = duration
        })
    elseif Config.notifySystem == 'brutal' then
        exports['brutal_notify']:SendAlert('Door Breach', message, duration, type)
    else
        print('Error: Invalid notification system configured')
    end
end

function GenerateToken()
    local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    local token = ''
    for i = 1, 20 do
        local randIndex = math.random(1, #chars)
        token = token .. chars:sub(randIndex, randIndex)
    end
    return token, os.time()
end

function HasRequiredItem(requiredItems)
    if Config.inventorySystem == 'ox' then
        for _, item in ipairs(requiredItems) do
            local count = exports.ox_inventory:Search('count', item)
            if count and count > 0 then
                return true
            end
        end
    elseif Config.inventorySystem == 'qb' then
        for _, item in ipairs(requiredItems) do
            if QBCore.Functions.HasItem(item) then
                return true
            end
        end
    elseif Config.inventorySystem == 'qs' then
        for _, item in ipairs(requiredItems) do
            local hasItem = exports['qs']:HasItem(item, 1)
            if hasItem then
                return true
            end
        end
    elseif Config.inventorySystem == 'lj' then
        for _, item in ipairs(requiredItems) do
            if exports['lj-inventory']:HasItem(item, 1) then
                return true
            end
        end
    else
        print('Error: Invalid inventory system configured')
        return false
    end
    return false
end

function IsPlayerAllowedToBreach()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    for _, gang in ipairs(Config.allowedGangs) do
        if PlayerData.gang.name == gang then
            return true
        end
    end

    for _, job in ipairs(Config.allowedJobs) do
        if PlayerData.job.name == job then
            return true
        end
    end
    
    return false
end

function GetRequiredItem()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    for _, gang in ipairs(Config.allowedGangs) do
        if PlayerData.gang.name == gang then
            return Config.gangItems
        end
    end

    for _, job in ipairs(Config.allowedJobs) do
        if PlayerData.job.name == job then
            return Config.jobItems
        end
    end
    
    return {}
end

function CanUseBreach(action)
    local ClosestDoor = exports.ox_doorlock:getClosestDoor()
    if not ClosestDoor then 
        SendNotify('No door found', 'error', 3000)
        return false
    end 

    if Config.useSpecificDoors then
        local doorName = ClosestDoor.name
        local isAllowedDoor = false
        for _, allowedDoor in ipairs(Config.specificDoors) do
            if doorName == allowedDoor then
                isAllowedDoor = true
                break
            end
        end
        if not isAllowedDoor then
            SendNotify('This door cannot be breached', 'error', 3000)
            return false
        end
    end

    return action == 'breakdoor' and ClosestDoor.state == 1
end

CreateThread(function()
    exports.ox_target:addGlobalObject({
        {
            name = 'breakdoor',
            label = 'Break the door down',
            icon = 'fas fa-user-lock',
            canInteract = function()
                local ClosestDoor = exports.ox_doorlock:getClosestDoor()
                local currentTime = GetGameTimer()
                return ClosestDoor and CanUseBreach('breakdoor') and ClosestDoor.distance <= 1.5 and (currentTime - lastBreachTime) >= Config.breachCooldown
            end,
            event = 'luke-door:client:breakdoor',
            items = GetRequiredItem(), 
            anyItem = true, 
            distance = 1
        }
    })
end)

RegisterNetEvent('luke-door:client:breakdoor', function()
    local ClosestDoor = exports.ox_doorlock:getClosestDoor()

    if not IsPlayerAllowedToBreach() then
        return SendNotify('You cannot breach the compound', 'error', 3000)
    end

    if ClosestDoor.distance > 1.5 then
        return SendNotify('There are no doors close enough to you', 'error', 3000)
    end

    local requiredItems = GetRequiredItem()
    if not HasRequiredItem(requiredItems) then
        return SendNotify('You need a breaching tool to break this door', 'error', 3000)
    end

    local token, timestamp = GenerateToken()

    TriggerServerEvent('luke-door:server:registerToken', token, timestamp, ClosestDoor.id)

    local coords = ClosestDoor.coords
    local Ped = PlayerPedId()

    TaskTurnPedToFaceCoord(Ped, coords.x, coords.y, coords.z, 2000)
    Wait(500)

    if ClosestDoor.state == 0 then
        if lib.progressCircle({
            duration = 4000,
            position = 'bottom',
            label = 'Locking door...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true,
            },
            anim = {
                scenario = 'PROP_HUMAN_PARKING_METER',
            },
        }) then
            TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 1, token, timestamp)
        else
            SendNotify('You have cancelled breaching the compound', 'error', 3000)
        end
    else
        if Config.useSkillCheck then
            exports['ps-ui']:Thermite(function(success)
                if success then
                    Wait(2000)
                    exports['ps-ui']:Circle(function(success)
                        if success then
                            Wait(2000)
                            exports['ps-ui']:Circle(function(success)
                                if success then
                                    PerformBreach(ClosestDoor, token, timestamp)
                                else
                                    HandleBreachFailure(ClosestDoor, token, timestamp)
                                end
                            end, 5, 7)
                        else
                            HandleBreachFailure(ClosestDoor, token, timestamp)
                        end
                    end, 10, 10)
                else
                    HandleBreachFailure(ClosestDoor, token, timestamp)
                end
            end, 10, 6, 2)
        else
            PerformBreach(ClosestDoor, token, timestamp)
        end
    end

    StopAnimTask(PlayerPedId(), "amb@prop_human_bum_bin@base", "base", 1.0)
    ClearPedTasks(PlayerPedId())
end)

function PerformBreach(ClosestDoor, token, timestamp)
    exports['progressbar']:Progress({
        name = "compoundbreach",
        duration = 5000,
        label = "Smashing the Door Open",
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = true,
            disableCombat = true,
        },
        animation = {
            animDict = "missheistfbi3b_ig7",
            anim = "lift_fibagent_loop",
        },
    }, function(cancelled)
        if not cancelled then
            TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 0, token, timestamp)
            SendNotify('You have managed to storm ram the door open', 'success', 3000)
            Wait(600000)
            TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 1, token, timestamp)
            lastBreachTime = GetGameTimer()
        else
            SendNotify('You have cancelled stormramming the door open', 'error', 3000)
        end
    end)
end

function HandleBreachFailure(ClosestDoor, token, timestamp)
    SendNotify('You have failed to storm ram the door open', 'error', 3000)
    local chance = math.random(1, 100)
    if chance <= 10 then
        TriggerServerEvent('luke-door:server:breachremove', ClosestDoor.id, token, timestamp)
    end
end
