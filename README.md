# QB-carradio
# 🎵 QB-CarRadio - Advanced Vehicle Radio System

A feature-rich car radio system for QBCore FiveM servers with real-time synchronization, 10-band equalizer, and distance-based audio.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![FiveM](https://img.shields.io/badge/FiveM-QBCore-blue.svg)
![Version](https://img.shields.io/badge/version-2.0-green.svg)

## ✨ Features

### 🎶 **Core Features**
- **Real-Time Audio Sync** - Players join songs at the exact current timestamp
- **Distance-Based Audio** - Volume fades naturally based on proximity to vehicles
- **Per-Vehicle Independence** - Each vehicle has its own isolated radio system
- **YouTube & Direct Audio Support** - Play YouTube videos or direct MP3/OGG/WAV links
- **Save Favorite Songs** - Personal music library saved per player

### 🎚️ **Advanced Features**
- **10-Band Equalizer** - Professional EQ (31Hz to 16kHz) with real-time sync
- **EQ Presets** - Save and load up to 10 custom EQ configurations
- **Multi-Player Sync** - All nearby players hear the same audio simultaneously
- **Volume Control** - Real-time volume adjustments without audio restart
- **Smart Auto-Play** - Music automatically starts/stops based on player proximity

### 🎨 **User Interface**
- Modern, responsive design
- Tabbed interface (Player, Equalizer, Saved Music)
- Visual EQ sliders with real-time feedback
- Easy-to-use controls

---
### **Dependencies**
- ✅ [Xsound](https://github.com/Xogy/xsound) required
- ✅ [QBCore Framework](https://github.com/qbcore-framework/qb-core)
- ✅ [oxmysql](https://github.com/overextended/oxmysql) or mysql-async
- ✅ [qb-inventory](https://github.com/qbcore-framework/qb-inventory) (or compatible inventory)

### **Database**
- MySQL 5.7+ or MariaDB 10.2+

### **Server**
- FiveM Server artifact 5181 or higher
- Server configured with OneSync enabled (recommended)

---
![Screenshot](https://media.discordapp.net/attachments/606279825635934210/1454684794603704362/image.png?ex=6951fc49&is=6950aac9&hm=2ebf8fb0442bbf0312997de9ecd6d72073a73648e74d12412e43236410da7be9&=&format=webp&quality=lossless)
## 🚀 Installation

### **Step 1: Download & Extract**
1. Download the latest release
2. Extract the `qb-carradio` folder to your server's `resources` directory

### **Step 2: Database Setup**
Run the following SQL in your database:

```sql
-- Main tables
-- Car Radio SQL Installation
-- This will create the necessary tables for the car radio system

-- Main car_radios table
CREATE TABLE IF NOT EXISTS `car_radios` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(50) NOT NULL,
    `owner` VARCHAR(50) NOT NULL,
    `url` TEXT,
    `volume` INT DEFAULT 50,
    `timestamp` INT DEFAULT 0,
    `playing` TINYINT(1) DEFAULT 0,
    `is_advanced` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Saved music table for users
CREATE TABLE IF NOT EXISTS `saved_music` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `url` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add EQ settings column to car_radios table (for equalizer functionality)
ALTER TABLE `car_radios` 
ADD COLUMN IF NOT EXISTS `eq_settings` TEXT DEFAULT NULL;

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_plate ON car_radios(plate);
CREATE INDEX IF NOT EXISTS idx_owner ON car_radios(owner);

-- Migration for existing installations (run this if upgrading)
-- ALTER TABLE car_radios ADD COLUMN IF NOT EXISTS timestamp INT DEFAULT 0;
-- ALTER TABLE car_radios ADD COLUMN IF NOT EXISTS is_advanced TINYINT(1) DEFAULT 0;
```

### **Step 3: Add Items to Inventory**
Add these items to your `qb-core/shared/items.lua`:

```lua
carradio = { name = 'carradio', label = 'Car Radio', weight = 500, type = 'item', image = 'carradio.png', unique = false, useable = true, shouldClose = true, combinable = nil, description = 'A high-quality car radio for listening to music'},
```

### **Step 4: Add to Server Config**
Add to your `server.cfg`:

```cfg
ensure qb-carradio
```

### **Step 5: start Server**
```

---

## 🎮 Usage

### **Installing a Radio**
1. Get a `carradio` item
2. Sit in the driver's seat of a vehicle
3. Use the item from your inventory
4. Wait 5 seconds for installation

### **Opening the Radio**
- Press **F6** (default key, configurable in `config.lua`)
- Only works if a radio is installed in the vehicle

### **Playing Music**

#### **YouTube Videos:**
1. Copy a YouTube URL (e.g., `https://www.youtube.com/watch?v=dQw4w9WgXcQ`)
2. Paste it into the URL field
3. Click Play ▶️

#### **Direct Audio (MP3/OGG/WAV):**
1. Get a direct audio link (e.g., `https://example.com/song.mp3`)
2. Paste it into the URL field
3. Click Play ▶️

### **Using the Equalizer**
1. Click the **Equalizer** tab
2. Adjust the 10 frequency bands (31Hz to 16kHz)
3. Everyone nearby hears the EQ changes in real-time
4. Save presets by **holding** a preset button (1-10)
5. Load presets by **clicking** the button

### **Saving Favorite Songs**
1. Enter a URL in the player
2. Click the **Bookmark** icon 🔖
3. Enter a name for the song
4. Access saved songs in the **Saved** tab

---

## ⚙️ Configuration

Edit `config.lua` to customize:

```lua
-- Radio Controls
Config.OpenRadioKey = 'F6' -- Key to open radio GUI
Config.ToggleRadioKey = 'HOME' -- Quick play/pause toggle

-- Distance & Volume
Config.MaxRadioDistance = 30.0 -- Max hearing distance (meters)
Config.VolumeDecreaseRate = 0.03 -- Volume fade per meter
Config.DefaultVolume = 50 -- Default volume (0-100)

-- Installation Time
Config.InstallTime = 5000 -- Time to install (ms)
Config.RemoveTime = 3000 -- Time to remove (ms)
```

---

## 🔧 Important Notes

### **⚠️ EQ (Equalizer) Limitations**
- **✅ Works with:** Direct audio files (MP3, OGG, WAV, M4A, AAC, FLAC)
- **❌ Does NOT work with:** YouTube videos (browser limitation)
- All players hear EQ changes in real-time
- EQ settings are saved per vehicle

### **🎵 Audio Sync**
- Players automatically join songs at the current timestamp
- Works exactly like a real radio - no restarts needed
- Volume changes sync to all players instantly

### **📡 Distance System**
- Audio fades naturally based on distance
- Inside vehicle = full volume
- Outside vehicle = distance-based fade
- Beyond 30m (default) = silent

### **🔄 Multi-Player Support**
- Multiple vehicles can play different songs simultaneously
- Each vehicle's radio is completely independent
- No interference between radios

---

## 🐛 Troubleshooting

### **"Unknown column 'eq_settings' in 'field list'"**
**Fix:** Run this SQL:
```sql
ALTER TABLE `car_radios` ADD COLUMN `eq_settings` TEXT DEFAULT NULL;
```

### **EQ Not Working**
- Make sure you're using a **direct audio file** (MP3/OGG), not YouTube
- Verify the radio is installed in the vehicle
- Check that the audio is actually playing

### **Radio Not Opening**
- Check if a radio is installed (`/removecarradio` to reset)
- Verify you're in the driver's seat
- Make sure the keybind is correct in `config.lua`

### **Volume Not Syncing**
- Restart the resource: `restart qb-carradio`
- Check server console for errors
- Ensure all players have the latest files

---

## 📝 Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/removecarradio` | Remove radio from current vehicle | Admin only |

---

## 🎯 How It Works

### **Real-Time Sync**
```lua
-- When Player 1 starts a song at 00:00
Server records: startTime = GetGameTimer()

-- When Player 2 joins 30 seconds later
Client calculates: elapsed = (currentTime - startTime) / 1000 = 30 seconds
Audio seeks to: 30 seconds

Result: Both players hear the song at 30 seconds!
```

### **Distance-Based Audio**
```lua
-- Every 500ms:
1. Calculate distance from player to each vehicle
2. If distance < 30m: volume = baseVolume * (1 - distance * 0.03)
3. If distance > 30m: volume = 0 (silent)
4. Update audio gain in real-time
```

### **EQ Synchronization**
```lua
-- When you adjust EQ:
Client → Server → All Clients
All players' audio filters update instantly
```

---

## 📦 File Structure

```
qb-carradio/
├── fxmanifest.lua
├── config.lua
├── client/
│   └── client.lua
├── server/
│   └── server.lua
└── html/
    ├── index.html
    ├── style.css
    └── script.js
```

---

## 🤝 Support

- **Issues:** [GitHub Issues](https://github.com/Betches-jr/QB-carradio/issues)
---

## 📜 License

This project is licensed under the MIT License

---

## 🌟 Credits

- **Framework:** [QBCore](https://github.com/qbcore-framework)
- **Audio System:** Web Audio API with 10-band parametric EQ
- **YouTube Integration:** YouTube IFrame API

---

## 💡 Tips

1. **For best quality:** Use direct MP3 links instead of YouTube
2. **Save bandwidth:** Lower quality audio files load faster
3. **EQ Presets:** Save different EQ configurations for different music genres
4. **Distance:** Adjust `Config.MaxRadioDistance` for your server's needs

---

## 🔄 Changelog

### Version 2.0
- ✨ Real-time audio synchronization
- ✨ 10-band equalizer with presets
- ✨ Distance-based audio system
- ✨ Per-vehicle audio independence
- 🐛 Fixed volume sync issues
- 🐛 Fixed EQ not syncing to other players
- 🎨 Cleaned code and removed debug logs


---

Made with ❤️ for the FiveM community
