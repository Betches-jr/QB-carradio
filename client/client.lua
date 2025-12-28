local QBCore = exports['qb-core']:GetCoreObject()
local currentVehicle = nil
local currentPlate = nil
local isRadioOpen = false
local radioInstalled = false
local isAdvanced = false
local currentRadioData = {}

-- Store all active radios by plate
local activeRadios = {}

-- Track which radios are currently playing for this client
local playingRadios = {} -- [plate] = true/false

-- Distance-based volume system
local function CalculateDistanceVolume(plate, baseVolume)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    
    -- Find the vehicle with this plate
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(vehicle)
        if vehPlate and string.gsub(vehPlate, '^%s*(.-)%s*$', '%1') == plate then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(playerCoords - vehCoords)
            
            -- If player is in this vehicle, full volume
            if playerVehicle == vehicle then
                return baseVolume / 100.0
            end
            
            -- If player is outside, apply distance-based falloff
            if distance <= Config.MaxRadioDistance then
                local volumeMultiplier = 1.0 - (distance * Config.VolumeDecreaseRate)
                if volumeMultiplier < 0 then volumeMultiplier = 0 end
                return (baseVolume / 100.0) * volumeMultiplier
            else
                return 0 -- Too far away
            end
        end
    end
    
    return 0 -- Vehicle not found
end

-- Track which radios are currently playing for this client
local playingRadios = {} -- [plate] = true/false

-- Update all active radios based on distance
CreateThread(function()
    while true do
        Wait(500) -- Check every 500ms
        
        for plate, radioData in pairs(activeRadios) do
            if radioData.playing and radioData.url and radioData.url ~= '' then
                local volume = CalculateDistanceVolume(plate, radioData.volume or 50)
                
                if volume > 0 then
                    -- Player is in range
                    if not playingRadios[plate] then
                        -- Start playing this radio for this player AT CURRENT TIMESTAMP
                        playingRadios[plate] = true
                        
                        -- Calculate current timestamp (how far into the song we should be)
                        local currentTime = GetGameTimer()
                        local songStartTime = radioData.startTime or currentTime
                        local elapsedSeconds = (currentTime - songStartTime) / 1000
                        
                        SendNUIMessage({
                            action = 'playAdvancedAudio',
                            plate = plate,
                            url = radioData.url,
                            volume = volume,
                            timestamp = elapsedSeconds
                        })
                        
                        if radioData.eqSettings then
                            Wait(250)
                            SendNUIMessage({
                                action = 'setEQ',
                                plate = plate,
                                eq = radioData.eqSettings
                            })
                        end
                    else
                        -- Already playing, just update volume
                        SendNUIMessage({
                            action = 'updateAdvancedDistance',
                            plate = plate,
                            volume = volume
                        })
                    end
                else
                    -- Too far away
                    if playingRadios[plate] then
                        -- Stop playing for this player
                        playingRadios[plate] = false
                        SendNUIMessage({
                            action = 'stopAdvancedAudio',
                            plate = plate
                        })
                    end
                end
            else
                -- Radio is not playing
                if playingRadios[plate] then
                    playingRadios[plate] = false
                    SendNUIMessage({
                        action = 'stopAdvancedAudio',
                        plate = plate
                    })
                end
            end
        end
    end
end)

-- Open Radio GUI
RegisterNetEvent('qb-carradio:client:openRadio', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        QBCore.Functions.Notify(Config.Notifications.notInVehicle, 'error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1') -- Trim whitespace
    
    -- Check if radio is installed
    QBCore.Functions.TriggerCallback('qb-carradio:server:isInstalled', function(installed, radioData)
        if not installed then
            QBCore.Functions.Notify(Config.Notifications.noRadio, 'error')
            return
        end
        
        currentVehicle = vehicle
        currentPlate = plate
        radioInstalled = true
        isAdvanced = radioData.isAdvanced or false
        isRadioOpen = true
        
        -- Get saved music
        QBCore.Functions.TriggerCallback('qb-carradio:server:getSavedMusic', function(savedMusic)
            -- Get current radio state from server
            QBCore.Functions.TriggerCallback('qb-carradio:server:getRadioState', function(state)
                currentRadioData = state or {}
                
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action = 'open',
                    plate = plate,
                    data = {
                        url = currentRadioData.url or '',
                        volume = currentRadioData.volume or Config.DefaultVolume,
                        playing = currentRadioData.playing or false,
                        timestamp = currentRadioData.timestamp or 0,
                        eq = currentRadioData.eq or nil
                    },
                    savedMusic = savedMusic,
                    isAdvanced = isAdvanced
                })
            end, plate)
        end)
    end, plate)
end)

-- Close Radio GUI
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isRadioOpen = false
    
    SendNUIMessage({
        action = 'close'
    })
    
    cb('ok')
end)

-- Play Music
RegisterNUICallback('play', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    local url = data.url
    local volume = data.volume or Config.DefaultVolume
    
    -- Update server state with start time
    TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
        url = url,
        playing = true,
        volume = volume,
        timestamp = 0,
        startTime = GetGameTimer()
    })
    
    currentRadioData.url = url
    currentRadioData.playing = true
    currentRadioData.volume = volume
    currentRadioData.timestamp = 0
    currentRadioData.startTime = GetGameTimer()
    
    cb('ok')
end)

-- Pause Music
RegisterNUICallback('pause', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
        playing = false,
        timestamp = data.timestamp or 0
    })
    
    currentRadioData.playing = false
    currentRadioData.timestamp = data.timestamp or 0
    
    cb('ok')
end)

-- Resume Music
RegisterNUICallback('resume', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
        playing = true
    })
    
    currentRadioData.playing = true
    
    cb('ok')
end)

-- Stop Music
RegisterNUICallback('stop', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
        url = '',
        playing = false,
        timestamp = 0
    })
    
    currentRadioData.url = ''
    currentRadioData.playing = false
    currentRadioData.timestamp = 0
    
    cb('ok')
end)

-- Update Volume
RegisterNUICallback('updateVolume', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    local volume = data.volume or Config.DefaultVolume
    
    -- Update server state - THIS WILL SYNC TO ALL PLAYERS
    TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
        volume = volume
    })
    
    currentRadioData.volume = volume
    
    cb('ok')
end)

-- Update EQ Settings
RegisterNUICallback('updateEQ', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:updateEQ', currentPlate, data.eq)
    TriggerServerEvent('qb-carradio:server:saveVehicleEQ', currentPlate, data.eq)
    
    cb('ok')
end)

-- Save EQ Preset
RegisterNUICallback('savePreset', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:savePreset', currentPlate, data.slot, data.values)
    cb('ok')
end)

-- Load EQ Preset
RegisterNUICallback('loadPreset', function(data, cb)
    if not currentPlate then
        cb('error')
        return
    end
    
    TriggerServerEvent('qb-carradio:server:loadPreset', currentPlate, data.slot)
    cb('ok')
end)

-- Save Music
RegisterNUICallback('saveMusic', function(data, cb)
    TriggerServerEvent('qb-carradio:server:saveMusic', data.name, data.url)
    cb('ok')
end)

-- Delete Music
RegisterNUICallback('deleteMusic', function(data, cb)
    TriggerServerEvent('qb-carradio:server:deleteMusic', data.id)
    cb('ok')
end)

-- Refresh Saved Music
RegisterNetEvent('qb-carradio:client:refreshSavedMusic', function()
    if not isRadioOpen then return end
    
    QBCore.Functions.TriggerCallback('qb-carradio:server:getSavedMusic', function(savedMusic)
        SendNUIMessage({
            action = 'updateSavedMusic',
            savedMusic = savedMusic
        })
    end)
end)

-- Sync Radio State (from server to all clients)
RegisterNetEvent('qb-carradio:client:syncRadio', function(plate, data)
    if not plate or not data then return end
    
    -- Check if this is just a volume change
    local isVolumeOnlyChange = false
    if activeRadios[plate] then
        if activeRadios[plate].url == data.url and 
           activeRadios[plate].playing == data.playing and
           activeRadios[plate].volume ~= data.volume then
            isVolumeOnlyChange = true
        end
    end
    
    -- Store this radio's state with start time
    local oldData = activeRadios[plate]
    activeRadios[plate] = {
        url = data.url,
        playing = data.playing,
        volume = data.volume or 50,
        timestamp = data.timestamp or 0,
        startTime = data.startTime or GetGameTimer(),
        eqSettings = data.eqSettings or (oldData and oldData.eqSettings) or nil
    }
    
    -- If song just started playing, record start time
    if not oldData or not oldData.playing or oldData.url ~= data.url then
        if data.playing and data.url and data.url ~= '' then
            activeRadios[plate].startTime = GetGameTimer()
        end
    elseif oldData and oldData.startTime then
        -- Keep the original start time if song hasn't changed
        activeRadios[plate].startTime = oldData.startTime
    end
    
    -- If it's just a volume change, don't restart the audio
    if isVolumeOnlyChange then
        -- Just update the volume, don't restart
        local volume = CalculateDistanceVolume(plate, data.volume or 50)
        if volume > 0 and playingRadios[plate] then
            SendNUIMessage({
                action = 'updateAdvancedDistance',
                plate = plate,
                volume = volume
            })
        end
        
        -- Update UI if this is current vehicle
        if plate == currentPlate and isRadioOpen then
            currentRadioData = data
            SendNUIMessage({
                action = 'updateUI',
                data = data
            })
        end
        return
    end
    
    -- Calculate distance-based volume for this player
    local volume = CalculateDistanceVolume(plate, data.volume or 50)
    
    if data.playing and data.url and data.url ~= '' then
        if volume > 0 then
            -- Calculate elapsed time for real-time sync
            local currentTime = GetGameTimer()
            local songStartTime = activeRadios[plate].startTime
            local elapsedSeconds = (currentTime - songStartTime) / 1000
            
            -- Play the audio for this vehicle at current timestamp
            playingRadios[plate] = true
            SendNUIMessage({
                action = 'playAdvancedAudio',
                plate = plate,
                url = data.url,
                volume = volume,
                timestamp = elapsedSeconds
            })
            
            if activeRadios[plate].eqSettings then
                Wait(250)
                SendNUIMessage({
                    action = 'setEQ',
                    plate = plate,
                    eq = activeRadios[plate].eqSettings
                })
            end
        else
            playingRadios[plate] = false
        end
    else
        -- Stop the audio for this vehicle
        playingRadios[plate] = false
        SendNUIMessage({
            action = 'stopAdvancedAudio',
            plate = plate
        })
    end
    
    -- If this is the current vehicle, update the UI
    if plate == currentPlate and isRadioOpen then
        currentRadioData = data
        SendNUIMessage({
            action = 'updateUI',
            data = data
        })
    end
end)

-- Sync EQ Settings
RegisterNetEvent('qb-carradio:client:syncEQ', function(plate, eqSettings)
    if not plate or not eqSettings then return end
    
    if activeRadios[plate] then
        activeRadios[plate].eqSettings = eqSettings
    end
    
    SendNUIMessage({
        action = 'setEQ',
        plate = plate,
        eq = eqSettings
    })
    
    if plate == currentPlate and isRadioOpen then
        SendNUIMessage({
            action = 'updateEQUI',
            eq = eqSettings
        })
    end
end)

-- Apply Preset (server response)
RegisterNetEvent('qb-carradio:client:applyPreset', function(slot, values)
    SendNUIMessage({
        action = 'loadedPreset',
        slot = slot,
        values = values
    })
end)

-- Stop Radio (when removed)
RegisterNetEvent('qb-carradio:client:stopRadio', function(plate)
    activeRadios[plate] = nil
    
    SendNUIMessage({
        action = 'stopAdvancedAudio',
        plate = plate
    })
    
    if plate == currentPlate then
        currentRadioData = {}
    end
end)

-- Install Radio
RegisterNetEvent('qb-carradio:client:tryInstall', function(advanced)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        QBCore.Functions.Notify(Config.Notifications.notInVehicle, 'error')
        return
    end
    
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver ~= ped then
        QBCore.Functions.Notify(Config.Notifications.notDriver, 'error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    QBCore.Functions.Progressbar('install_radio', Config.Notifications.installing, Config.InstallTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local vehModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        TriggerServerEvent('qb-carradio:server:installRadio', plate, vehModel, advanced)
    end, function() -- Cancel
    end)
end)

-- Radio Installed Confirmation
RegisterNetEvent('qb-carradio:client:radioInstalled', function(plate, advanced)
    radioInstalled = true
    isAdvanced = advanced
    currentPlate = plate
end)

-- Admin Remove
RegisterNetEvent('qb-carradio:client:adminRemove', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        QBCore.Functions.Notify(Config.Notifications.notInVehicle, 'error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    TriggerServerEvent('qb-carradio:server:removeRadio', plate)
end)

-- Key Mapping for Opening Radio
RegisterCommand('opencarradio', function()
    TriggerEvent('qb-carradio:client:openRadio')
end)

RegisterKeyMapping('opencarradio', 'Open Car Radio', 'keyboard', Config.OpenRadioKey)

-- Quick Toggle Play/Pause
RegisterCommand('togglecarradio', function()
    if not currentPlate or not radioInstalled then return end
    
    if currentRadioData.playing then
        TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
            playing = false
        })
    else
        TriggerServerEvent('qb-carradio:server:updateRadio', currentPlate, {
            playing = true
        })
    end
end)

RegisterKeyMapping('togglecarradio', 'Toggle Car Radio', 'keyboard', Config.ToggleRadioKey)

-- Vehicle Exit Cleanup
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        -- Player exited vehicle
        if vehicle == 0 and currentVehicle ~= nil then
            currentVehicle = nil
            currentPlate = nil
            radioInstalled = false
            
            if isRadioOpen then
                SendNUIMessage({ action = 'close' })
                SetNuiFocus(false, false)
                isRadioOpen = false
            end
        elseif vehicle ~= 0 and vehicle ~= currentVehicle then
            -- Player changed vehicles
            currentVehicle = vehicle
            local plate = GetVehicleNumberPlateText(vehicle)
            currentPlate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
            
            -- Check if new vehicle has radio
            QBCore.Functions.TriggerCallback('qb-carradio:server:isInstalled', function(installed, radioData)
                radioInstalled = installed
                if installed then
                    isAdvanced = radioData.isAdvanced or false
                end
            end, currentPlate)
        end
    end
end)

-- Auto-sync all active radios when player joins
CreateThread(function()
    Wait(5000) -- Wait for player to fully load
    
    QBCore.Functions.TriggerCallback('qb-carradio:server:getAllActiveRadios', function(radios)
        if radios then
            for plate, data in pairs(radios) do
                activeRadios[plate] = data
                
                -- Calculate volume based on distance and start playing
                local volume = CalculateDistanceVolume(plate, data.volume or 50)
                if volume > 0 and data.playing and data.url then
                    playingRadios[plate] = true
                    
                    -- Calculate elapsed time
                    local currentTime = GetGameTimer()
                    local songStartTime = data.startTime or currentTime
                    local elapsedSeconds = (currentTime - songStartTime) / 1000
                    
                    SendNUIMessage({
                        action = 'playAdvancedAudio',
                        plate = plate,
                        url = data.url,
                        volume = volume,
                        timestamp = elapsedSeconds
                    })
                    
                    -- Apply EQ settings if vehicle has them
                    if data.eqSettings then
                        Wait(250)
                        SendNUIMessage({
                            action = 'setEQ',
                            plate = plate,
                            eq = data.eqSettings
                        })
                    end
                end
            end
        end
    end)
end)
