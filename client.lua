local QBCore = exports['qb-core']:GetCoreObject()

local allowedGangs = {'lostmc', 'ballas', 'triads'}  -- Add more gangs here
local allowedJobs = {'police', 'sherrif'}  -- Add more jobs here

function IsPlayerAllowedToBreach()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    -- Check if player is in an allowed gang
    for _, gang in ipairs(allowedGangs) do
        if PlayerData.gang.name == gang then
            return true
        end
    end

    -- Check if player is in an allowed job
    for _, job in ipairs(allowedJobs) do
        if PlayerData.job.name == job then
            return true
        end
    end
    
    return false
end

function CanUseBreach(action)
    local ClosestDoor = exports.ox_doorlock:getClosestDoor()
    if not ClosestDoor then 
        exports['okokNotify']:Alert('Doorlock', 'No door found', 3000, 'error', false)
        return false
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
                return ClosestDoor and CanUseBreach('breakdoor') and ClosestDoor.distance <= 1.5
            end,
            event = 'luke-door:client:breakdoor',
            items = 'police_stormram',
            anyItem = false,
            distance = 1
        }
    })
end)

RegisterNetEvent('luke-door:client:breakdoor', function()
    local ClosestDoor = exports.ox_doorlock:getClosestDoor()

    if not IsPlayerAllowedToBreach() then
        return exports['okokNotify']:Alert('Doorlock', 'You cannot breach the compound', 3000, 'error', false)
    end

    if ClosestDoor.distance > 1.5 then
        return exports['okokNotify']:Alert('Doorlock', "There are no doors close enough to you", 3000, 'error', false)
    end

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
            TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 1)
        else
            exports['okokNotify']:Alert('Door Breach', 'You have cancelled breaching the compound', 3000, 'error', false)
        end
    else
        exports['ps-ui']:Thermite(function(success)
            if success then
                Wait(2000)
                exports['ps-ui']:Circle(function(success)
                    if success then
                        Wait(2000)
                        exports['ps-ui']:Circle(function(success)
                            if success then
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
                                        TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 0)
                                        exports['okokNotify']:Alert('Door Breach', 'You have managed to storm ram the door open', 3000, 'success', false)
                                        Wait(600000)
                                        TriggerServerEvent('luke-door:server:setState', ClosestDoor.id, 1)
                                    else
                                        exports['okokNotify']:Alert('Door Breach', 'You have cancelled stormramming the door open', 3000, 'error', false)
                                        local chance = math.random(1, 100)
                                        if chance <= 90 then
                                            print(success)
                                        else
                                            TriggerServerEvent('luke-door:server:breachremove')
                                        end
                                    end
                                end)
                            else
                                exports['okokNotify']:Alert('Door Breach', 'You have Failed to Storm Ram the door open', 3000, 'error', false)
                                local chance = math.random(1, 100)
                                if chance <= 90 then
                                    print(success)
                                else
                                    TriggerServerEvent('luke-door:server:breachremove')
                                end
                            end
                        end, 5, 7) -- NumberOfCircles, MS
                    else
                        exports['okokNotify']:Alert('Door Breach', 'You have Failed to Storm Ram the door open', 3000, 'error', false)
                        local chance = math.random(1, 100)
                        if chance <= 90 then
                            print(success)
                        else
                            TriggerServerEvent('luke-door:server:breachremove')
                        end
                    end
                end, 10, 10) -- NumberOfCircles, MS
            end
        end, 10, 6, 2)  -- Number of Circles, Time in milliseconds
    end

    StopAnimTask(PlayerPedId(), "amb@prop_human_bum_bin@base", "base", 1.0)
    ClearPedTasks(PlayerPedId())
end)
