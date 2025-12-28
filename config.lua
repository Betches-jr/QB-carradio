Config = {}

-- General Settings
Config.UseTarget = false -- Set to true if using qb-target
Config.MaxRadioDistance = 30.0 -- Maximum distance to hear radio from outside vehicle (in meters)
Config.VolumeDecreaseRate = 0.03 -- How much volume decreases per meter outside vehicle

-- Item Settings
Config.ItemName = 'carradio' -- Basic radio item name
Config.AdvancedItemName = 'advancedradio' -- Advanced radio with equalizer
Config.InstallTime = 5000 -- Time in ms to install radio (5 seconds)
Config.RemoveTime = 3000 -- Time in ms to remove radio (3 seconds)

-- Radio Controls
Config.OpenRadioKey = 'Y' -- Key to open radio GUI when installed
Config.ToggleRadioKey = 'HOME' -- Quick toggle play/pause

-- Volume Settings
Config.DefaultVolume = 50 -- Default volume (0-100)
Config.MaxVolume = 100
Config.MinVolume = 0

-- GUI Settings
Config.UIPosition = 'center' -- Position of UI: 'center', 'top-right', 'top-left', 'bottom-right', 'bottom-left'

-- Notifications
Config.Notifications = {
    installing = 'Installing car radio...',
    installed = 'Car radio installed successfully!',
    removing = 'Removing car radio...',
    removed = 'Car radio removed!',
    noRadio = 'This vehicle doesn\'t have a radio installed!',
    notInVehicle = 'You must be in a vehicle!',
    notDriver = 'You must be the driver to install/remove the radio!',
    alreadyInstalled = 'This vehicle already has a radio installed!',
    invalidUrl = 'Invalid YouTube URL!',
    playingMusic = 'Now playing music...',
    musicPaused = 'Music paused',
    musicResumed = 'Music resumed'
}
