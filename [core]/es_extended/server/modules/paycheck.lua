function StartPayCheck()
    CreateThread(function()
        while true do
            Wait(Config.PaycheckInterval)
            
            -- Optimize: batch process players in smaller chunks to prevent server lag
            local playerCount = 0
            local playerList = {}
            
            for player, xPlayer in pairs(ESX.Players) do
                if xPlayer.paycheckEnabled then
                    playerList[#playerList + 1] = {player = player, xPlayer = xPlayer}
                    playerCount = playerCount + 1
                end
            end
            
            if playerCount == 0 then
                goto continue
            end
            
            -- Process players in batches to prevent server lag spikes
            local batchSize = math.max(5, math.ceil(playerCount / 10)) -- Process max 10 batches
            local processed = 0
            
            while processed < playerCount do
                local batchEnd = math.min(processed + batchSize, playerCount)
                
                for i = processed + 1, batchEnd do
                    local playerData = playerList[i]
                    if playerData and playerData.xPlayer and ESX.Players[playerData.player] then -- Ensure player is still online
                        ProcessPaycheck(playerData.player, playerData.xPlayer)
                    end
                end
                
                processed = batchEnd
                
                -- Small delay between batches to prevent lag
                if processed < playerCount then
                    Wait(100)
                end
            end
            
            ::continue::
        end
    end)
end

function ProcessPaycheck(player, xPlayer)
    local jobLabel = xPlayer.job.label
    local job = xPlayer.job.grade_name
    local onDuty = xPlayer.job.onDuty
    local salary = (job == "unemployed" or onDuty) and xPlayer.job.grade_salary or ESX.Math.Round(xPlayer.job.grade_salary * Config.OffDutyPaycheckMultiplier)

    if salary <= 0 then
        return
    end

    if job == "unemployed" then -- unemployed
        xPlayer.addAccountMoney("bank", salary, "Welfare Check")
        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_help", salary), "CHAR_BANK_MAZE", 9)
        
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - Unemployment Benefits", "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
    elseif Config.EnableSocietyPayouts then -- possibly a society
        -- Use async callback to prevent blocking
        TriggerEvent("esx_society:getSociety", xPlayer.job.name, function(society)
            if society ~= nil then -- verified society
                TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
                    if account and account.money >= salary then -- does the society have money to pay its employees?
                        xPlayer.addAccountMoney("bank", salary, "Paycheck")
                        account.removeMoney(salary)
                        
                        if Config.LogPaycheck then
                            ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                                { name = "Player", value = xPlayer.name, inline = true },
                                { name = "ID", value = xPlayer.source, inline = true },
                                { name = "Amount", value = salary, inline = true },
                            })
                        end

                        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                    else
                        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
                    end
                end)
            else -- not a society
                xPlayer.addAccountMoney("bank", salary, "Paycheck")
                
                if Config.LogPaycheck then
                    ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                        { name = "Player", value = xPlayer.name, inline = true },
                        { name = "ID", value = xPlayer.source, inline = true },
                        { name = "Amount", value = salary, inline = true },
                    })
                end
                
                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
            end
        end)
    else -- generic job
        xPlayer.addAccountMoney("bank", salary, "Paycheck")
        
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - Generic", "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
        
        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
    end
end
