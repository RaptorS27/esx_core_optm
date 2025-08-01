local pickups = {}

ESX.SecureNetEvent("esx:requestModel", function(model)
    ESX.Streaming.RequestModel(model)
end)

RegisterNetEvent("esx:playerLoaded", function(xPlayer, _, skin)
    ESX.PlayerData = xPlayer

    if not Config.Multichar then
        ESX.SpawnPlayer(skin, ESX.PlayerData.coords, function()
            TriggerEvent("esx:onPlayerSpawn")
            TriggerEvent("esx:restoreLoadout")
            TriggerServerEvent("esx:onPlayerSpawn")
            TriggerEvent("esx:loadingScreenOff")
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
        end)
    end

    while not DoesEntityExist(ESX.PlayerData.ped) do
        Wait(20)
    end

    ESX.PlayerLoaded = true

    local timer = GetGameTimer()
    while not HaveAllStreamingRequestsCompleted(ESX.PlayerData.ped) and (GetGameTimer() - timer) < 2000 do
        Wait(0)
    end

    Adjustments:Load()

    ClearPedTasksImmediately(ESX.PlayerData.ped)

    if not Config.Multichar then
        Core.FreezePlayer(false)
    end

    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    Actions:Init()
    StartPointsLoop()
    StartServerSyncLoops()
    NetworkSetLocalPlayerSyncLookAt(true)
end)

local isFirstSpawn = true
ESX.SecureNetEvent("esx:onPlayerLogout", function()
    ESX.PlayerLoaded = false
    isFirstSpawn = true
end)

ESX.SecureNetEvent("esx:setMaxWeight", function(newMaxWeight)
    ESX.SetPlayerData("maxWeight", newMaxWeight)
end)

local function onPlayerSpawn()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", false)
end

AddEventHandler("playerSpawned", onPlayerSpawn)
AddEventHandler("esx:onPlayerSpawn", function()
    onPlayerSpawn()

    if isFirstSpawn then
        isFirstSpawn = false

        if ESX.PlayerData.metadata.health and (ESX.PlayerData.metadata.health > 0 or Config.SaveDeathStatus) then
            SetEntityHealth(ESX.PlayerData.ped, ESX.PlayerData.metadata.health)
        end

        if ESX.PlayerData.metadata.armor and ESX.PlayerData.metadata.armor > 0 then
            SetPedArmour(ESX.PlayerData.ped, ESX.PlayerData.metadata.armor)
        end
    end
end)

AddEventHandler("esx:onPlayerDeath", function()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", true)
end)

AddEventHandler("skinchanger:modelLoaded", function()
    while not ESX.PlayerLoaded do
        Wait(100)
    end
    TriggerEvent("esx:restoreLoadout")
end)

AddEventHandler("esx:restoreLoadout", function()
    ESX.SetPlayerData("ped", PlayerPedId())

    if not Config.CustomInventory then
        local ammoTypes = {}
        RemoveAllPedWeapons(ESX.PlayerData.ped, true)

        for _, v in ipairs(ESX.PlayerData.loadout) do
            local weaponName = v.name
            local weaponHash = joaat(weaponName)

            GiveWeaponToPed(ESX.PlayerData.ped, weaponHash, 0, false, false)
            SetPedWeaponTintIndex(ESX.PlayerData.ped, weaponHash, v.tintIndex)

            local ammoType = GetPedAmmoTypeFromWeapon(ESX.PlayerData.ped, weaponHash)

            for _, v2 in ipairs(v.components) do
                local componentHash = ESX.GetWeaponComponent(weaponName, v2).hash
                GiveWeaponComponentToPed(ESX.PlayerData.ped, weaponHash, componentHash)
            end

            if not ammoTypes[ammoType] then
                AddAmmoToPed(ESX.PlayerData.ped, weaponHash, v.ammo)
                ammoTypes[ammoType] = true
            end
        end
    end
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("VehicleProperties", nil, function(bagName, _, value)
    if not value then
        return
    end

    bagName = bagName:gsub("entity:", "")
    local netId = tonumber(bagName)
    if not netId then
        error("Tried to set vehicle properties with invalid netId")
        return
    end

    local vehicle = NetToVeh(netId)

    local tries = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) do
        Wait(200)
        tries = tries + 1
        if tries > 20 then
            return error(("Invalid entity - ^5%s^7!"):format(netId))
        end
    end

    if NetworkGetEntityOwner(vehicle) ~= ESX.playerId then
        return
    end

    ESX.Game.SetVehicleProperties(vehicle, value)
end)

ESX.SecureNetEvent("esx:setAccountMoney", function(account)
    for i = 1, #ESX.PlayerData.accounts do
        if ESX.PlayerData.accounts[i].name == account.name then
            ESX.PlayerData.accounts[i] = account
            break
        end
    end

    ESX.SetPlayerData("accounts", ESX.PlayerData.accounts)
end)

if not Config.CustomInventory then
    ESX.SecureNetEvent("esx:addInventoryItem", function(item, count, showNotification)
        for k, v in ipairs(ESX.PlayerData.inventory) do
            if v.name == item then
                ESX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
                ESX.PlayerData.inventory[k].count = count
                break
            end
        end

        if showNotification then
            ESX.UI.ShowInventoryItemNotification(true, item, count)
        end
    end)

    ESX.SecureNetEvent("esx:removeInventoryItem", function(item, count, showNotification)
        for i = 1, #ESX.PlayerData.inventory do
            if ESX.PlayerData.inventory[i].name == item then
                ESX.UI.ShowInventoryItemNotification(false, ESX.PlayerData.inventory[i].label, ESX.PlayerData.inventory[i].count - count)
                ESX.PlayerData.inventory[i].count = count
                break
            end
        end

        if showNotification then
            ESX.UI.ShowInventoryItemNotification(false, item, count)
        end
    end)

    RegisterNetEvent("esx:addWeapon", function()
        error("event ^5'esx:addWeapon'^1 Has Been Removed. Please use ^5xPlayer.addWeapon^1 Instead!")
    end)


    RegisterNetEvent("esx:addWeaponComponent", function()
        error("event ^5'esx:addWeaponComponent'^1 Has Been Removed. Please use ^5xPlayer.addWeaponComponent^1 Instead!")
    end)

    RegisterNetEvent("esx:setWeaponAmmo", function()
        error("event ^5'esx:setWeaponAmmo'^1 Has Been Removed. Please use ^5xPlayer.addWeaponAmmo^1 Instead!")
    end)

    ESX.SecureNetEvent("esx:setWeaponTint", function(weapon, weaponTintIndex)
        SetPedWeaponTintIndex(ESX.PlayerData.ped, joaat(weapon), weaponTintIndex)
    end)

    RegisterNetEvent("esx:removeWeapon", function()
        error("event ^5'esx:removeWeapon'^1 Has Been Removed. Please use ^5xPlayer.removeWeapon^1 Instead!")
    end)

    ESX.SecureNetEvent("esx:removeWeaponComponent", function(weapon, weaponComponent)
        local componentHash = ESX.GetWeaponComponent(weapon, weaponComponent).hash
        RemoveWeaponComponentFromPed(ESX.PlayerData.ped, joaat(weapon), componentHash)
    end)
end

ESX.SecureNetEvent("esx:setJob", function(Job)
    ESX.SetPlayerData("job", Job)
end)

ESX.SecureNetEvent("esx:setGroup", function(group)
    ESX.SetPlayerData("group", group)
end)

if not Config.CustomInventory then
    ESX.SecureNetEvent("esx:createPickup", function(pickupId, label, coords, itemType, name, components, tintIndex)
        local function setObjectProperties(object)
            SetEntityAsMissionEntity(object, true, false)
            PlaceObjectOnGroundProperly(object)
            FreezeEntityPosition(object, true)
            SetEntityCollision(object, false, true)

            pickups[pickupId] = {
                obj = object,
                label = label,
                inRange = false,
                coords = coords,
            }
        end

        if itemType == "item_weapon" then
            local weaponHash = joaat(name)
            ESX.Streaming.RequestWeaponAsset(weaponHash)
            local pickupObject = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
            SetWeaponObjectTintIndex(pickupObject, tintIndex)

            for _, v in ipairs(components) do
                local component = ESX.GetWeaponComponent(name, v)
                if component then
                    GiveWeaponComponentToWeaponObject(pickupObject, component.hash)
                end
            end

            setObjectProperties(pickupObject)
        else
            ESX.Game.SpawnLocalObject("prop_money_bag_01", coords, setObjectProperties)
        end
    end)

    ESX.SecureNetEvent("esx:createMissingPickups", function(missingPickups)
        for pickupId, pickup in pairs(missingPickups) do
            TriggerEvent("esx:createPickup", pickupId, pickup.label, vector3(pickup.coords.x, pickup.coords.y, pickup.coords.z - 1.0), pickup.type, pickup.name, pickup.components, pickup.tintIndex)
        end
    end)
end

ESX.SecureNetEvent("esx:registerSuggestions", function(registeredCommands)
    for name, command in pairs(registeredCommands) do
        if command.suggestion then
            TriggerEvent("chat:addSuggestion", ("/%s"):format(name), command.suggestion.help, command.suggestion.arguments)
        end
    end
end)

if not Config.CustomInventory then
    ESX.SecureNetEvent("esx:removePickup", function(pickupId)
        if pickups[pickupId] and pickups[pickupId].obj then
            ESX.Game.DeleteObject(pickups[pickupId].obj)
            pickups[pickupId] = nil
        end
    end)
end

function StartServerSyncLoops()
    if Config.CustomInventory then return end

    local currentWeapon = {
        ---@type number
        ---@diagnostic disable-next-line: assign-type-mismatch
        hash = `WEAPON_UNARMED`,
        ammo = 0,
        lastUpdateTime = 0,
        config = nil
    }

    -- Cache weapon configs to avoid repeated lookups
    local weaponConfigCache = {}

    local function updateCurrentWeaponAmmo(weaponName)
        local currentTime = GetGameTimer()
        -- Rate limit ammo updates to prevent spam
        if currentTime - currentWeapon.lastUpdateTime < 250 then
            return
        end
        
        local newAmmo = GetAmmoInPedWeapon(ESX.PlayerData.ped, currentWeapon.hash)

        if newAmmo ~= currentWeapon.ammo then
            currentWeapon.ammo = newAmmo
            currentWeapon.lastUpdateTime = currentTime
            TriggerServerEvent("esx:updateWeaponAmmo", weaponName, newAmmo)
        end
    end

    -- Optimized weapon sync thread with better caching and reduced native calls
    CreateThread(function()
        local lastWeaponCheck = 0
        local weaponCheckInterval = 500 -- Check weapon changes every 500ms instead of 250ms
        
        while ESX.PlayerLoaded do
            local currentTime = GetGameTimer()
            
            -- Reduce frequency of weapon checks
            if currentTime - lastWeaponCheck >= weaponCheckInterval then
                lastWeaponCheck = currentTime
                local selectedWeapon = GetSelectedPedWeapon(ESX.PlayerData.ped)
                
                -- Only process if weapon actually changed
                if selectedWeapon ~= currentWeapon.hash then
                    currentWeapon.hash = selectedWeapon
                    
                    if currentWeapon.hash ~= `WEAPON_UNARMED` then
                        -- Use cached weapon config or fetch and cache it
                        local weaponConfig = weaponConfigCache[currentWeapon.hash]
                        if not weaponConfig then
                            weaponConfig = ESX.GetWeaponFromHash(currentWeapon.hash)
                            if weaponConfig then
                                weaponConfigCache[currentWeapon.hash] = weaponConfig
                            end
                        end
                        
                        currentWeapon.config = weaponConfig
                        if weaponConfig then
                            currentWeapon.ammo = GetAmmoInPedWeapon(ESX.PlayerData.ped, currentWeapon.hash)
                        end
                    else
                        currentWeapon.config = nil
                    end
                end
            end
            
            -- Update ammo for current weapon if it exists
            if currentWeapon.config and currentWeapon.hash == GetSelectedPedWeapon(ESX.PlayerData.ped) then
                updateCurrentWeaponAmmo(currentWeapon.config.name)
            end
            
            Wait(500) -- Increased wait time for better performance
        end
    end)

    -- Optimized parachute monitoring thread
    CreateThread(function()
        local PARACHUTE_OPENING <const> = 1
        local PARACHUTE_OPEN <const> = 2
        local lastParachuteCheck = 0
        local parachuteUpdateSent = false

        while ESX.PlayerLoaded do
            local currentTime = GetGameTimer()
            
            -- Check parachute state less frequently
            if currentTime - lastParachuteCheck >= 1000 then
                lastParachuteCheck = currentTime
                local parachuteState = GetPedParachuteState(ESX.PlayerData.ped)

                if (parachuteState == PARACHUTE_OPENING or parachuteState == PARACHUTE_OPEN) and not parachuteUpdateSent then
                    TriggerServerEvent("esx:updateWeaponAmmo", "GADGET_PARACHUTE", 0)
                    parachuteUpdateSent = true
                    
                    -- Monitor until parachute is closed
                    CreateThread(function()
                        while GetPedParachuteState(ESX.PlayerData.ped) ~= -1 do 
                            Wait(1000) 
                        end
                        parachuteUpdateSent = false
                    end)
                elseif parachuteState == -1 then
                    parachuteUpdateSent = false
                end
            end
            
            Wait(1000) -- Increased wait time since parachute state doesn't change frequently
        end
    end)
end

if not Config.CustomInventory and Config.EnableDefaultInventory then
    ESX.RegisterInput("showinv", TranslateCap("keymap_showinventory"), "keyboard", "F2", function()
        if not ESX.PlayerData.dead then
            ESX.ShowInventory()
        end
    end)
end

if not Config.CustomInventory then
    -- Optimized pickup system with spatial indexing and reduced distance calculations
    CreateThread(function()
        local lastPlayerCoords = vector3(0, 0, 0)
        local coordsUpdateTimer = 0
        local closestPickupDistance = 999.0
        local activePickups = {}
        
        while true do
            local currentTime = GetGameTimer()
            local Sleep = 1000
            
            -- Update player coordinates less frequently to reduce CPU usage
            if currentTime - coordsUpdateTimer > 500 then -- Update every 500ms instead of every frame
                lastPlayerCoords = GetEntityCoords(ESX.PlayerData.ped)
                coordsUpdateTimer = currentTime
                
                -- Pre-filter pickups by distance to reduce loop iterations
                activePickups = {}
                for pickupId, pickup in pairs(pickups) do
                    local distance = #(lastPlayerCoords - pickup.coords)
                    if distance < 10 then -- Slightly larger radius for pre-filtering
                        activePickups[pickupId] = {pickup = pickup, distance = distance}
                    elseif pickup.inRange then
                        pickup.inRange = false -- Clear range flag for distant pickups
                    end
                end
            end
            
            -- Only check closest pickup to reduce processing
            local nearbyPickup = nil
            closestPickupDistance = 999.0
            
            for pickupId, data in pairs(activePickups) do
                if data.distance < closestPickupDistance then
                    closestPickupDistance = data.distance
                    nearbyPickup = {id = pickupId, data = data.pickup, distance = data.distance}
                end
            end
            
            if nearbyPickup and nearbyPickup.distance < 5 then
                Sleep = 100 -- Faster updates when near pickups
                local pickup = nearbyPickup.data
                local label = pickup.label
                
                if nearbyPickup.distance < 1.2 then -- Slightly larger pickup radius
                    if IsControlJustReleased(0, 38) then
                        -- Cache ped checks to avoid repeated native calls
                        local isPedOnFoot = IsPedOnFoot(ESX.PlayerData.ped)
                        if isPedOnFoot and not pickup.inRange then
                            -- Get closest player distance only when needed
                            local _, closestDistance = ESX.Game.GetClosestPlayer(lastPlayerCoords)
                            if closestDistance == -1 or closestDistance > 3 then
                                pickup.inRange = true
                                
                                -- Optimize animation loading and playing
                                local dict, anim = "weapons@first_person@aim_rng@generic@projectile@sticky_bomb@", "plant_floor"
                                ESX.Streaming.RequestAnimDict(dict)
                                TaskPlayAnim(ESX.PlayerData.ped, dict, anim, 8.0, 1.0, 1000, 16, 0.0, false, false, false)
                                RemoveAnimDict(dict)
                                Wait(1000)
                                
                                TriggerServerEvent("esx:onPickup", nearbyPickup.id)
                                PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                            end
                        end
                    end
                    
                    label = ("%s~n~%s"):format(label, TranslateCap("threw_pickup_prompt"))
                end
                
                -- Only draw text for the closest pickup to reduce draw calls
                local textCoords = pickup.coords + vector3(0.0, 0.0, 0.25)
                ESX.Game.Utils.DrawText3D(textCoords, label, 1.2, 1)
            end
            
            -- Clear inRange flag for pickups that are no longer close
            for pickupId, pickup in pairs(pickups) do
                if pickup.inRange and (not nearbyPickup or nearbyPickup.id ~= pickupId) then
                    local distance = #(lastPlayerCoords - pickup.coords)
                    if distance > 1.5 then
                        pickup.inRange = false
                    end
                end
            end
            
            Wait(Sleep)
        end
    end)
end

----- Admin commands from esx_adminplus
ESX.SecureNetEvent("esx:tpm", function()
    local GetEntityCoords = GetEntityCoords
    local GetGroundZFor_3dCoord = GetGroundZFor_3dCoord
    local GetFirstBlipInfoId = GetFirstBlipInfoId
    local DoesBlipExist = DoesBlipExist
    local DoScreenFadeOut = DoScreenFadeOut
    local GetBlipInfoIdCoord = GetBlipInfoIdCoord
    local GetVehiclePedIsIn = GetVehiclePedIsIn

    ESX.TriggerServerCallback("esx:isUserAdmin", function(admin)
        if not admin then
            return
        end
        local blipMarker = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blipMarker) then
            ESX.ShowNotification(TranslateCap("tpm_nowaypoint"), "error")
            return "marker"
        end

        -- Fade screen to hide how clients get teleported.
        DoScreenFadeOut(650)
        while not IsScreenFadedOut() do
            Wait(0)
        end

        local ped, coords = ESX.PlayerData.ped, GetBlipInfoIdCoord(blipMarker)
        local vehicle = GetVehiclePedIsIn(ped, false)
        local oldCoords = GetEntityCoords(ped)

        -- Unpack coords instead of having to unpack them while iterating.
        -- 825.0 seems to be the max a player can reach while 0.0 being the lowest.
        local x, y, groundZ, Z_START = coords["x"], coords["y"], 850.0, 950.0
        local found = false
        FreezeEntityPosition(vehicle > 0 and vehicle or ped, true)

        for i = Z_START, 0, -25.0 do
            local z = i
            if (i % 2) ~= 0 then
                z = Z_START - i
            end

            NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
            local curTime = GetGameTimer()
            while IsNetworkLoadingScene() do
                if GetGameTimer() - curTime > 1000 then
                    break
                end
                Wait(0)
            end
            NewLoadSceneStop()
            SetPedCoordsKeepVehicle(ped, x, y, z)

            while not HasCollisionLoadedAroundEntity(ped) do
                RequestCollisionAtCoord(x, y, z)
                if GetGameTimer() - curTime > 1000 then
                    break
                end
                Wait(0)
            end

            -- Get ground coord. As mentioned in the natives, this only works if the client is in render distance.
            found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
            if found then
                Wait(0)
                SetPedCoordsKeepVehicle(ped, x, y, groundZ)
                break
            end
            Wait(0)
        end

        -- Remove black screen once the loop has ended.
        DoScreenFadeIn(650)
        FreezeEntityPosition(vehicle > 0 and vehicle or ped, false)

        if not found then
            -- If we can't find the coords, set the coords to the old ones.
            -- We don't unpack them before since they aren't in a loop and only called once.
            SetPedCoordsKeepVehicle(ped, oldCoords["x"], oldCoords["y"], oldCoords["z"] - 1.0)
            ESX.ShowNotification(TranslateCap("tpm_success"), "success")
        end

        -- If Z coord was found, set coords in found coords.
        SetPedCoordsKeepVehicle(ped, x, y, groundZ)
        ESX.ShowNotification(TranslateCap("tpm_success"), "success")
    end)
end)

local noclip = false
local noclip_pos = vector3(0, 0, 70)
local heading = 0

local function noclipThread()
    while noclip do
        SetEntityCoordsNoOffset(ESX.PlayerData.ped, noclip_pos.x, noclip_pos.y, noclip_pos.z, false, false, true)

        if IsControlPressed(1, 34) then
            heading = heading + 1.5
            if heading > 360 then
                heading = 0
            end

            SetEntityHeading(ESX.PlayerData.ped, heading)
        end

        if IsControlPressed(1, 9) then
            heading = heading - 1.5
            if heading < 0 then
                heading = 360
            end

            SetEntityHeading(ESX.PlayerData.ped, heading)
        end

        if IsControlPressed(1, 8) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 1.0, 0.0)
        end

        if IsControlPressed(1, 32) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, -1.0, 0.0)
        end

        if IsControlPressed(1, 27) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 0.0, 1.0)
        end

        if IsControlPressed(1, 173) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 0.0, -1.0)
        end
        Wait(0)
    end
end

ESX.SecureNetEvent("esx:noclip", function()
    ESX.TriggerServerCallback("esx:isUserAdmin", function(admin)
        if not admin then
            return
        end

        if not noclip then
            noclip_pos = GetEntityCoords(ESX.PlayerData.ped, false)
            heading = GetEntityHeading(ESX.PlayerData.ped)
        end

        noclip = not noclip
        if noclip then
            CreateThread(noclipThread)
        end

        if noclip then
            ESX.ShowNotification(TranslateCap("noclip_message", Translate("enabled")), "success")
        else
            ESX.ShowNotification(TranslateCap("noclip_message", Translate("disabled")), "error")
        end
    end)
end)

ESX.SecureNetEvent("esx:killPlayer", function()
    SetEntityHealth(ESX.PlayerData.ped, 0)
end)

ESX.SecureNetEvent("esx:repairPedVehicle", function()
    local ped = ESX.PlayerData.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    SetVehicleEngineHealth(vehicle, 1000)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0)
end)

ESX.SecureNetEvent("esx:freezePlayer", function(input)
    if input == "freeze" then
        SetEntityCollision(ESX.PlayerData.ped, false, false)
        FreezeEntityPosition(ESX.PlayerData.ped, true)
        SetPlayerInvincible(ESX.playerId, true)
    elseif input == "unfreeze" then
        SetEntityCollision(ESX.PlayerData.ped, true, true)
        FreezeEntityPosition(ESX.PlayerData.ped, false)
        SetPlayerInvincible(ESX.playerId, false)
    end
end)

ESX.RegisterClientCallback("esx:GetVehicleType", function(cb, model)
    cb(ESX.GetVehicleTypeClient(model))
end)

ESX.SecureNetEvent('esx:updatePlayerData', function(key, val)
	ESX.SetPlayerData(key, val)
end)

---@param command string
ESX.SecureNetEvent("esx:executeCommand", function(command)
    ExecuteCommand(command)
end)

AddEventHandler("onResourceStop", function(resource)
    if Core.Events[resource] then
        for i = 1, #Core.Events[resource] do
            RemoveEventHandler(Core.Events[resource][i])
        end
    end
end)
