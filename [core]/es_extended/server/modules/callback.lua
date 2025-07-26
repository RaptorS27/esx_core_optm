---@diagnostic disable: duplicate-set-field

-- =============================================
-- MARK: Variables
-- =============================================

Callbacks = {}

Callbacks.requests = {}
Callbacks.storage = {}
Callbacks.id = 0

-- Performance optimizations for callback system
Callbacks.requestTimeouts = {}
Callbacks.cleanupTimer = 0
Callbacks.TIMEOUT_DURATION = 30000 -- 30 seconds timeout for callbacks
Callbacks.CLEANUP_INTERVAL = 60000 -- Cleanup every minute

-- =============================================
-- MARK: Internal Functions
-- =============================================

function Callbacks:Register(name, resource, cb)
    self.storage[name] = {
        resource = resource,
        cb = cb
    }
end

function Callbacks:Execute(cb, ...)
    local success, errorString = pcall(cb, ...)

    if not success then
        print(("[^1ERROR^7] Failed to execute Callback with RequestId: ^5%s^7"):format(self.currentId))
        print("^3Callback Error:^7 " .. tostring(errorString))  -- just log, don't throw
        self.currentId = nil
        return
    end

    self.currentId = nil
end

function Callbacks:Trigger(player, event, cb, invoker, ...)
    self.requests[self.id] = cb
    self.requestTimeouts[self.id] = GetGameTimer() + self.TIMEOUT_DURATION

    TriggerClientEvent("esx:triggerClientCallback", player, event, self.id, invoker, ...)

    self.id += 1
    
    -- Periodic cleanup of timed out requests
    local currentTime = GetGameTimer()
    if currentTime - self.cleanupTimer > self.CLEANUP_INTERVAL then
        self:CleanupTimedOutRequests()
        self.cleanupTimer = currentTime
    end
end

function Callbacks:CleanupTimedOutRequests()
    local currentTime = GetGameTimer()
    for requestId, timeout in pairs(self.requestTimeouts) do
        if currentTime > timeout then
            if self.requests[requestId] then
                self.requests[requestId] = nil
                self.requestTimeouts[requestId] = nil
                if Config.EnableDebug then
                    print(("[^3WARNING^7] Callback request ^5%s^7 timed out and was cleaned up"):format(requestId))
                end
            end
        end
    end
end

function Callbacks:ServerRecieve(player, event, requestId, invoker, ...)
    self.currentId = requestId

    if not self.storage[event] then
        return error(("Server Callback with requestId ^5%s^1 Was Called by ^5%s^1 but does not exist."):format(event, invoker))
    end

    local returnCb = function(...)
        TriggerClientEvent("esx:serverCallback", player, requestId, invoker, ...)
    end
    local callback = self.storage[event].cb

    self:Execute(callback, player, returnCb, ...)
end

function Callbacks:RecieveClient(requestId, invoker, ...)
    self.currentId = requestId

    if not self.requests[self.currentId] then
        return error(("Client Callback with requestId ^5%s^1 Was Called by ^5%s^1 but does not exist."):format(self.currentId, invoker))
    end

    local callback = self.requests[self.currentId]

    self:Execute(callback, ...)
    
    -- Clean up the completed request
    self.requests[requestId] = nil
    self.requestTimeouts[requestId] = nil
end

-- =============================================
-- MARK: ESX Functions
-- =============================================

---@param player number playerId
---@param eventName string
---@param callback function
---@param ... any
function ESX.TriggerClientCallback(player, eventName, callback, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "es_extended"

    Callbacks:Trigger(player, eventName, callback, invoker, ...)
end

---@param eventName string
---@param callback function
---@return nil
function ESX.RegisterServerCallback(eventName, callback)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "es_extended"

    Callbacks:Register(eventName, invoker, callback)
end

---@param eventName string
---@return boolean
function ESX.DoesServerCallbackExist(eventName)
    return Callbacks.storage[eventName] ~= nil
end

-- =============================================
-- MARK: Events
-- =============================================

RegisterNetEvent("esx:clientCallback", function(requestId, invoker, ...)
    Callbacks:RecieveClient(requestId, invoker, ...)
end)

RegisterNetEvent("esx:triggerServerCallback", function(eventName, requestId, invoker, ...)
    local source = source
    Callbacks:ServerRecieve(source, eventName, requestId, invoker, ...)
end)

AddEventHandler("onResourceStop", function(resource)
    for k, v in pairs(Callbacks.storage) do
        if v.resource == resource then
            Callbacks.storage[k] = nil
        end
    end
end)
