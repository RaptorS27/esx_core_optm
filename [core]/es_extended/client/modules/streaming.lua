ESX.Streaming = {}

-- Cache for loaded assets to prevent redundant requests
local assetCache = {
    models = {},
    textures = {},
    ptfx = {},
    animSets = {},
    animDicts = {},
    weapons = {}
}

-- Timeout handling for streaming requests
local STREAMING_TIMEOUT = 10000 -- 10 seconds timeout

---@param modelHash number | string
---@param cb? function
---@return number | nil
function ESX.Streaming.RequestModel(modelHash, cb)
    modelHash = type(modelHash) == "number" and modelHash or joaat(modelHash)

    if not IsModelInCdimage(modelHash) then 
        if Config.EnableDebug then
            print(("[^3WARNING^7] Model ^5%s^7 is not in CD image"):format(modelHash))
        end
        return 
    end

    -- Check cache first
    if assetCache.models[modelHash] and HasModelLoaded(modelHash) then
        return cb and cb(modelHash) or modelHash
    end

    RequestModel(modelHash)
    local startTime = GetGameTimer()
    
    while not HasModelLoaded(modelHash) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] Model ^5%s^7 failed to load within timeout"):format(modelHash))
            end
            return nil
        end
        Wait(100) -- Reduced wait time for faster loading
    end

    assetCache.models[modelHash] = true
    return cb and cb(modelHash) or modelHash
end

---@param textureDict string
---@param cb? function
---@return string | nil
function ESX.Streaming.RequestStreamedTextureDict(textureDict, cb)
    -- Check cache first
    if assetCache.textures[textureDict] and HasStreamedTextureDictLoaded(textureDict) then
        return cb and cb(textureDict) or textureDict
    end

    RequestStreamedTextureDict(textureDict, false)
    local startTime = GetGameTimer()

    while not HasStreamedTextureDictLoaded(textureDict) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] Texture dict ^5%s^7 failed to load within timeout"):format(textureDict))
            end
            return nil
        end
        Wait(100)
    end

    assetCache.textures[textureDict] = true
    return cb and cb(textureDict) or textureDict
end

---@param assetName string
---@param cb? function
---@return string | nil
function ESX.Streaming.RequestNamedPtfxAsset(assetName, cb)
    -- Check cache first
    if assetCache.ptfx[assetName] and HasNamedPtfxAssetLoaded(assetName) then
        return cb and cb(assetName) or assetName
    end

    RequestNamedPtfxAsset(assetName)
    local startTime = GetGameTimer()

    while not HasNamedPtfxAssetLoaded(assetName) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] PTFX asset ^5%s^7 failed to load within timeout"):format(assetName))
            end
            return nil
        end
        Wait(100)
    end

    assetCache.ptfx[assetName] = true
    return cb and cb(assetName) or assetName
end

---@param animSet string
---@param cb? function
---@return string | nil
function ESX.Streaming.RequestAnimSet(animSet, cb)
    -- Check cache first
    if assetCache.animSets[animSet] and HasAnimSetLoaded(animSet) then
        return cb and cb(animSet) or animSet
    end

    RequestAnimSet(animSet)
    local startTime = GetGameTimer()

    while not HasAnimSetLoaded(animSet) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] Anim set ^5%s^7 failed to load within timeout"):format(animSet))
            end
            return nil
        end
        Wait(100)
    end

    assetCache.animSets[animSet] = true
    return cb and cb(animSet) or animSet
end

---@param animDict string
---@param cb? function
---@return string | nil
function ESX.Streaming.RequestAnimDict(animDict, cb)
    -- Check cache first
    if assetCache.animDicts[animDict] and HasAnimDictLoaded(animDict) then
        return cb and cb(animDict) or animDict
    end

    RequestAnimDict(animDict)
    local startTime = GetGameTimer()

    while not HasAnimDictLoaded(animDict) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] Anim dict ^5%s^7 failed to load within timeout"):format(animDict))
            end
            return nil
        end
        Wait(100)
    end

    assetCache.animDicts[animDict] = true
    return cb and cb(animDict) or animDict
end

---@param weaponHash number | string
---@param cb? function
---@return string | number | nil
function ESX.Streaming.RequestWeaponAsset(weaponHash, cb)
    weaponHash = type(weaponHash) == "number" and weaponHash or joaat(weaponHash)
    
    -- Check cache first
    if assetCache.weapons[weaponHash] and HasWeaponAssetLoaded(weaponHash) then
        return cb and cb(weaponHash) or weaponHash
    end

    RequestWeaponAsset(weaponHash, 31, 0)
    local startTime = GetGameTimer()

    while not HasWeaponAssetLoaded(weaponHash) do 
        if GetGameTimer() - startTime > STREAMING_TIMEOUT then
            if Config.EnableDebug then
                print(("[^1ERROR^7] Weapon asset ^5%s^7 failed to load within timeout"):format(weaponHash))
            end
            return nil
        end
        Wait(100)
    end

    assetCache.weapons[weaponHash] = true
    return cb and cb(weaponHash) or weaponHash
end

-- Clean up cache periodically to prevent memory issues
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        
        -- Clean up models that are no longer loaded
        for hash, _ in pairs(assetCache.models) do
            if not HasModelLoaded(hash) then
                assetCache.models[hash] = nil
            end
        end
        
        -- Clean up other asset types
        for name, _ in pairs(assetCache.textures) do
            if not HasStreamedTextureDictLoaded(name) then
                assetCache.textures[name] = nil
            end
        end
        
        for name, _ in pairs(assetCache.animDicts) do
            if not HasAnimDictLoaded(name) then
                assetCache.animDicts[name] = nil
            end
        end
        
        for name, _ in pairs(assetCache.animSets) do
            if not HasAnimSetLoaded(name) then
                assetCache.animSets[name] = nil
            end
        end
    end
end)
