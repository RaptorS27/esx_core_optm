Core = {}
Core.Input = {}
Core.Events = {}

ESX.PlayerData = {}
ESX.PlayerLoaded = false
ESX.playerId = PlayerId()
ESX.serverId = GetPlayerServerId(ESX.playerId)

ESX.UI = {}
ESX.UI.Menu = {}
ESX.UI.Menu.RegisteredTypes = {}
ESX.UI.Menu.Opened = {}

ESX.Game = {}
ESX.Game.Utils = {}

-- Optimized player loading thread with exponential backoff
CreateThread(function()
    if Config.Multichar then return end -- Early return if multichar is enabled
    
    local checkInterval = 100
    local maxInterval = 1000
    local attempts = 0
    
    while true do
        if NetworkIsPlayerActive(ESX.playerId) then
            ESX.DisableSpawnManager()
            DoScreenFadeOut(0)
            Wait(500)
            TriggerServerEvent("esx:onPlayerJoined")
            break
        end
        
        -- Exponential backoff to reduce CPU usage while waiting
        attempts = attempts + 1
        if attempts > 5 then
            checkInterval = math.min(checkInterval * 1.2, maxInterval)
        end
        
        Wait(checkInterval)
    end
end)
