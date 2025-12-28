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