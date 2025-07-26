local activeMenu
local Debug = ESX.GetConfig().EnableDebug
local lastMenuState = nil
local menuUpdateTimer = 0

-- Performance optimization: batch NUI messages and reduce redundant calls
local pendingMessages = {}
local messageBatchTimer = 0

-- Global functions
-- [ Post | Open | Closed ]

function Post(fn, ...)
    local message = {
        func = fn,
        args = { ... },
    }
    
    -- Batch messages to reduce NUI overhead
    table.insert(pendingMessages, message)
    
    -- Process messages immediately for critical functions
    if fn == "Open" or fn == "Closed" then
        FlushPendingMessages()
    else
        -- Batch other messages for better performance
        local currentTime = GetGameTimer()
        if currentTime - messageBatchTimer > 16 then -- ~60fps batching
            FlushPendingMessages()
        end
    end
end

function FlushPendingMessages()
    if #pendingMessages > 0 then
        for _, message in ipairs(pendingMessages) do
            SendNUIMessage(message)
        end
        pendingMessages = {}
        messageBatchTimer = GetGameTimer()
    end
end

function Open(position, eles, onSelect, onClose, canClose)
    local canCloseMenu = canClose == nil and true or canClose
    
    -- Optimize: only update if menu actually changed
    local newMenuState = json.encode({position, eles, canCloseMenu})
    if lastMenuState == newMenuState and activeMenu then
        return -- Menu hasn't changed, no need to reopen
    end
    
    activeMenu = {
        position = position,
        eles = eles,
        canClose = canCloseMenu,
        onSelect = onSelect,
        onClose = onClose,
    }

    LocalPlayer.state:set("context:active", true)
    lastMenuState = newMenuState

    Post("Open", eles, position)
end

function Closed()
    SetNuiFocus(false, false)

    local menu = activeMenu
    local cb = menu and menu.onClose

    activeMenu = nil
    lastMenuState = nil

    LocalPlayer.state:set("context:active", false)

    if cb then
        cb(menu)
    end
end

-- Exports
-- [ Preview | Open | Close ]

exports("Preview", Open)

exports("Open", function(...)
    Open(...)
    SetNuiFocus(true, true)
end)

exports("Close", function()
    if not activeMenu then
        return
    end

    Post("Closed")

    Closed()
end)

exports("Refresh", function(eles, position)
    if not activeMenu then
        return
    end

    -- Only update if elements or position actually changed
    local newEles = eles or activeMenu.eles
    local newPosition = position or activeMenu.position
    
    if newEles == activeMenu.eles and newPosition == activeMenu.position then
        return -- No changes, skip update
    end

    activeMenu.eles = newEles
    activeMenu.position = newPosition

    Post("Open", activeMenu.eles, activeMenu.position)
end)

-- Performance optimization: batch NUI message processing
CreateThread(function()
    while true do
        FlushPendingMessages()
        Wait(16) -- ~60fps batching for non-critical messages
    end
end)

-- NUI Callbacks
-- [ closed | selected | changed ]

RegisterNUICallback("closed", function(_, cb)
    if not activeMenu or (activeMenu and not activeMenu.canClose) then
        return cb(false)
    end
    cb(true)
    Closed()
end)

RegisterNUICallback("selected", function(data, cb)
    if not activeMenu or not activeMenu.onSelect or not data.index then
        return
    end

    local index = tonumber(data.index)
    local ele = activeMenu.eles[index]

    if not ele or ele.input then
        return
    end

    activeMenu:onSelect(ele)
    if cb then
        cb("ok")
    end
end)

RegisterNUICallback("changed", function(data, cb)
    if not activeMenu or not data.index or not data.value then
        return
    end

    local index = tonumber(data.index)
    local ele = activeMenu.eles[index]

    if not ele or not ele.input then
        return
    end

    if ele.inputType == "number" then
        ele.inputValue = tonumber(data.value)

        if ele.inputMin then
            ele.inputValue = math.max(ele.inputMin, ele.inputValue)
        end

        if ele.inputMax then
            ele.inputValue = math.min(ele.inputMax, ele.inputValue)
        end
    elseif ele.inputType == "text" then
        ele.inputValue = data.value
    elseif ele.inputType == "radio" then
        ele.inputValue = data.value
    end
    if cb then
        cb("ok")
    end
end)

-- Keybind

local function focusPreview()
    if not activeMenu or not activeMenu.onSelect then
        return
    end

    SetNuiFocus(true, true)
end

if PREVIEW_KEYBIND then
    RegisterCommand("previewContext", focusPreview, false)

    RegisterKeyMapping("previewContext", "Preview Active Context", "keyboard", PREVIEW_KEYBIND)
end

exports("focusPreview", focusPreview)

-- Debug/Test
-- Commands:
-- [ ctx:preview | ctx:open | ctx:close | ctx:form ]

if Debug then
    local position = "right"

    local eles = {
        {
            unselectable = true,
            icon = "fas fa-info-circle",
            title = "Unselectable Item (Header/Label?)",
        },
        {
            icon = "fas fa-check",
            title = "Item A",
            description = "Some description here. Add some words to make the text overflow.",
        },
        {
            disabled = true,
            icon = "fas fa-times",
            title = "Disabled Item",
            description = "Some description here. Add some words to make the text overflow.",
        },
        {
            icon = "fas fa-check",
            title = "Item B",
            description = "Some description here. Add some words to make the text overflow.",
        },
    }

    local function onSelect(menu, ele)
        print("Ele selected", ele.title)

        if ele.name == "close" then
            exports["esx_context"]:Close()
        end

        if ele.name ~= "submit" then
            return
        end

        for _, element in ipairs(menu.eles) do
            if element.input then
                print(element.name, element.inputType, element.inputValue)
            end
        end

        exports["esx_context"]:Close()
    end

    local function onClose()
        print("Menu closed.")
    end

    RegisterCommand("ctx:preview", function()
        exports["esx_context"]:Preview(position, eles)
    end, false)

    RegisterCommand("ctx:open", function()
        exports["esx_context"]:Open(position, eles, onSelect, onClose)
    end, false)

    RegisterCommand("ctx:close", function()
        exports["esx_context"]:Close()
    end, false)

    RegisterCommand("ctx:form", function()
        local formMenu = {
            {
                unselectable = true,
                icon = "fas fa-info-circle",
                title = "Unselectable Item (Header/Label?)",
            },
            {
                icon = "",
                title = "Input Text",
                input = true,
                inputType = "text",
                inputPlaceholder = "Placeholder...",
                name = "firstname",
            },
            {
                icon = "",
                title = "Input Text",
                input = true,
                inputType = "text",
                inputPlaceholder = "Placeholder...",
                name = "lastname",
            },
            {
                icon = "",
                title = "Input Number",
                input = true,
                inputType = "number",
                inputPlaceholder = "Placeholder...",
                inputValue = 0,
                inputMin = 0,
                inputMax = 50,
                name = "age",
            },
            {
                icon = "fas fa-check",
                title = "Submit",
                name = "submit",
            },
        }

        exports["esx_context"]:Open(position, formMenu, onSelect, onClose)
    end, false)
end
