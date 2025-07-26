local points = {}

function ESX.CreatePointInternal(coords, distance, hidden, enter, leave)
	local point = {
		coords = coords,
		distance = distance,
		hidden = hidden,
		enter = enter,
		leave = leave,
		resource = GetInvokingResource()
	}
	local handle = ESX.Table.SizeOf(points) + 1
	points[handle] = point
	return handle
end

function ESX.RemovePointInternal(handle)
	points[handle] = nil
end

function ESX.HidePointInternal(handle, hidden)
	if points[handle] then
		points[handle].hidden = hidden
	end
end

function StartPointsLoop()
	CreateThread(function()
		local lastUpdate = 0
		local updateInterval = Config.PerformanceOptimization.DefaultThreadWait or 500
		local lastCoords = vector3(0, 0, 0)
		local coordsUpdateTimer = 0
		
		while true do
			local currentTime = GetGameTimer()
			
			-- Update coordinates less frequently
			if currentTime - coordsUpdateTimer > 250 then
				lastCoords = GetEntityCoords(ESX.PlayerData.ped)
				coordsUpdateTimer = currentTime
			end
			
			-- Skip processing if player hasn't moved much
			if currentTime - lastUpdate >= updateInterval then
				lastUpdate = currentTime
				
				-- Pre-filter points by checking if we need to process them
				local hasNearbyPoints = false
				for handle, point in pairs(points) do
					if not point.hidden then
						local distance = #(lastCoords - point.coords)
						local isNearby = distance <= point.distance
						
						if isNearby ~= point.nearby then
							hasNearbyPoints = true
							if isNearby then
								points[handle].nearby = true
								points[handle].enter()
							else
								points[handle].nearby = false
								points[handle].leave()
							end
						end
					end
				end
				
				-- Adjust update frequency based on activity
				if hasNearbyPoints then
					updateInterval = 250 -- Faster updates when there are nearby points
				else
					updateInterval = Config.PerformanceOptimization.DefaultThreadWait or 500
				end
			end
			
			Wait(math.min(updateInterval, 500))
		end
	end)
end


AddEventHandler('onResourceStop', function(resource)
	for handle, point in pairs(points) do
		if point.resource == resource then
			points[handle] = nil
		end
	end
end)