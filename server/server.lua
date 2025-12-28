local QBCore = exports['qb-core']:GetCoreObject()
local installedRadios = {} -- Format: [plate] = {owner = source, url = '', playing = false, volume = 50, timestamp = 0, startTime = 0}

-- Initialize database
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `car_radios` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `plate` VARCHAR(50) NOT NULL,
            `owner` VARCHAR(50) NOT NULL,
            `url` TEXT,
            `volume` INT DEFAULT 50,
            `timestamp` INT DEFAULT 0,
            `playing` TINYINT(1) DEFAULT 0,
            `is_advanced` TINYINT(1) DEFAULT 0,
            `eq_settings` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Add is_advanced column if it doesn't exist (for upgrades)
    MySQL.query([[
        ALTER TABLE `car_radios` 
        ADD COLUMN IF NOT EXISTS `is_advanced` TINYINT(1) DEFAULT 0
    ]])
    
    -- Add eq_settings column if it doesn't exist (for upgrades)
    MySQL.query([[
        ALTER TABLE `car_radios` 
        ADD COLUMN IF NOT EXISTS `eq_settings` TEXT DEFAULT NULL
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `saved_music` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(255) NOT NULL,
            `url` TEXT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY `idx_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- Load all installed radios on server start
CreateThread(function()
    Wait(1000)
    local result = MySQL.query.await('SELECT * FROM car_radios')
    if result then
        for _, radio in pairs(result) do
            installedRadios[radio.plate] = {
                owner = radio.owner,
                url = radio.url,
                playing = radio.playing == 1,
                volume = radio.volume,
                timestamp = radio.timestamp or 0,
                startTime = 0, -- Will be set when song starts playing
                isAdvanced = radio.is_advanced == 1,
                eqSettings = radio.eq_settings and json.decode(radio.eq_settings) or nil
            }
        end
        print('[qb-carradio] Loaded ' .. #result .. ' installed radios from database')
    end
end)

-- Install Radio
QBCore.Functions.CreateUseableItem(Config.ItemName, function(source, item)
    local src = source
    TriggerClientEvent('qb-carradio:client:tryInstall', src, false)
end)

-- Install Advanced Radio
QBCore.Functions.CreateUseableItem(Config.AdvancedItemName, function(source, item)
    local src = source
    TriggerClientEvent('qb-carradio:client:tryInstall', src, true)
end)

-- Server event to confirm installation
RegisterNetEvent('qb-carradio:server:installRadio', function(plate, vehicleModel, isAdvanced)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if radio already installed
    if installedRadios[plate] then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.alreadyInstalled, 'error')
        return
    end
    
    local itemName = isAdvanced and Config.AdvancedItemName or Config.ItemName
    
    -- Remove item from inventory
    if Player.Functions.RemoveItem(itemName, 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove', 1)
        
        -- Add to database
        MySQL.insert('INSERT INTO car_radios (plate, owner, volume, playing, is_advanced) VALUES (?, ?, ?, ?, ?)', {
            plate,
            Player.PlayerData.citizenid,
            Config.DefaultVolume,
            0,
            isAdvanced and 1 or 0
        })
        
        -- Add to memory
        installedRadios[plate] = {
            owner = Player.PlayerData.citizenid,
            url = '',
            playing = false,
            volume = Config.DefaultVolume,
            timestamp = 0,
            startTime = 0,
            isAdvanced = isAdvanced
        }
        
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.installed, 'success')
        TriggerClientEvent('qb-carradio:client:radioInstalled', src, plate, isAdvanced)
    end
end)

-- Remove Radio
RegisterNetEvent('qb-carradio:server:removeRadio', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if not installedRadios[plate] then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.noRadio, 'error')
        return
    end
    
    -- Stop music for everyone
    TriggerClientEvent('qb-carradio:client:stopRadio', -1, plate)
    
    -- Remove from database
    MySQL.query('DELETE FROM car_radios WHERE plate = ?', {plate})
    
    -- Remove from memory
    installedRadios[plate] = nil
    
    -- Give item back
    Player.Functions.AddItem(Config.ItemName, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ItemName], 'add', 1)
    TriggerClientEvent('QBCore:Notify', src, Config.Notifications.removed, 'success')
end)

-- Check if radio is installed
QBCore.Functions.CreateCallback('qb-carradio:server:isInstalled', function(source, cb, plate)
    cb(installedRadios[plate] ~= nil, installedRadios[plate])
end)

-- Update radio state (play/pause/url/volume)
RegisterNetEvent('qb-carradio:server:updateRadio', function(plate, data)
    local src = source
    
    if not installedRadios[plate] then return end
    
    -- Update memory
    if data.url ~= nil then
        installedRadios[plate].url = data.url
    end
    if data.playing ~= nil then
        installedRadios[plate].playing = data.playing
    end
    if data.volume ~= nil then
        installedRadios[plate].volume = data.volume
    end
    if data.timestamp ~= nil then
        installedRadios[plate].timestamp = data.timestamp
    end
    if data.startTime ~= nil then
        installedRadios[plate].startTime = data.startTime
    end
    
    -- Update database
    MySQL.update([[
        UPDATE car_radios 
        SET url = ?, playing = ?, volume = ?, timestamp = ?
        WHERE plate = ?
    ]], {
        installedRadios[plate].url or '',
        installedRadios[plate].playing and 1 or 0,
        installedRadios[plate].volume or 50,
        installedRadios[plate].timestamp or 0,
        plate
    })
    
    -- SYNC TO ALL PLAYERS
    -- This ensures everyone hears the same thing (volume changes, play/pause, etc.)
    TriggerClientEvent('qb-carradio:client:syncRadio', -1, plate, {
        url = installedRadios[plate].url or '',
        playing = installedRadios[plate].playing or false,
        volume = installedRadios[plate].volume or 50,
        timestamp = installedRadios[plate].timestamp or 0,
        startTime = installedRadios[plate].startTime or 0,
        eqSettings = installedRadios[plate].eqSettings or nil
    })
end)

-- Get current radio state
QBCore.Functions.CreateCallback('qb-carradio:server:getRadioState', function(source, cb, plate)
    if installedRadios[plate] then
        cb(installedRadios[plate])
    else
        cb(nil)
    end
end)

-- Update EQ settings
RegisterNetEvent('qb-carradio:server:updateEQ', function(plate, eqSettings)
    if not installedRadios[plate] then return end
    
    installedRadios[plate].eqSettings = eqSettings
    
    TriggerClientEvent('qb-carradio:client:syncEQ', -1, plate, eqSettings)
end)

-- Save Music
RegisterNetEvent('qb-carradio:server:saveMusic', function(name, url)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    MySQL.insert('INSERT INTO saved_music (citizenid, name, url) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid,
        name,
        url
    }, function(id)
        if id then
            TriggerClientEvent('QBCore:Notify', src, 'Music saved successfully!', 'success')
            TriggerClientEvent('qb-carradio:client:refreshSavedMusic', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to save music', 'error')
        end
    end)
end)

-- Delete Saved Music
RegisterNetEvent('qb-carradio:server:deleteMusic', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    MySQL.query('DELETE FROM saved_music WHERE id = ? AND citizenid = ?', {
        id,
        Player.PlayerData.citizenid
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('QBCore:Notify', src, 'Music deleted!', 'success')
            TriggerClientEvent('qb-carradio:client:refreshSavedMusic', src)
        end
    end)
end)

-- Get Saved Music
QBCore.Functions.CreateCallback('qb-carradio:server:getSavedMusic', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb({})
        return 
    end
    
    MySQL.query('SELECT * FROM saved_music WHERE citizenid = ? ORDER BY created_at DESC', {
        Player.PlayerData.citizenid
    }, function(result)
        cb(result or {})
    end)
end)

-- Admin command to remove radio
QBCore.Commands.Add('removecarradio', 'Remove car radio from vehicle (Admin Only)', {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-carradio:client:adminRemove', src)
end, 'admin')

-- ============================================
-- 10-BAND EQ PRESET SYSTEM
-- ============================================

-- Save EQ preset
RegisterNetEvent('qb-carradio:server:savePreset', function(plate, slot, values)
    local src = source
    
    if not plate or not slot or not values then return end
    
    -- Convert values array to JSON
    local eqJson = json.encode(values)
    
    -- Save to database (upsert)
    MySQL.insert('INSERT INTO car_radio_presets (plate, preset_slot, eq_values) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE eq_values = ?', {
        plate, slot, eqJson, eqJson
    }, function(result)
        if result then
            TriggerClientEvent('QBCore:Notify', src, 'EQ Preset ' .. slot .. ' saved', 'success')
        end
    end)
end)

-- Load EQ preset
RegisterNetEvent('qb-carradio:server:loadPreset', function(plate, slot)
    local src = source
    
    if not plate or not slot then return end
    
    MySQL.query('SELECT eq_values FROM car_radio_presets WHERE plate = ? AND preset_slot = ?', {
        plate, slot
    }, function(result)
        if result and result[1] then
            local values = json.decode(result[1].eq_values)
            TriggerClientEvent('qb-carradio:client:applyPreset', src, slot, values)
        else
            TriggerClientEvent('QBCore:Notify', src, 'No preset saved in slot ' .. slot, 'error')
        end
    end)
end)

-- Save EQ settings for vehicle
RegisterNetEvent('qb-carradio:server:saveVehicleEQ', function(plate, eqValues)
    if not plate or not eqValues then return end
    
    local eqJson = json.encode(eqValues)
    
    MySQL.update('UPDATE car_radios SET eq_settings = ? WHERE plate = ?', {
        eqJson, plate
    })
end)

-- ============================================
-- GET ALL ACTIVE RADIOS (for auto-sync)
-- ============================================

QBCore.Functions.CreateCallback('qb-carradio:server:getAllActiveRadios', function(source, cb)
    local activeRadios = {}
    
    for plate, data in pairs(installedRadios) do
        if data.playing and data.url and data.url ~= '' then
            activeRadios[plate] = {
                url = data.url,
                volume = data.volume or 50,
                playing = data.playing,
                isAdvanced = data.isAdvanced or false,
                eqSettings = data.eqSettings or nil,
                startTime = data.startTime or 0
            }
        end
    end
    
    cb(activeRadios)
end)
