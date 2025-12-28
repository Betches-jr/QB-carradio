let isPlaying = false;
let isAdvanced = false;
let savedMusicData = [];
let updateInterval = null;
let equalizerInterval = null;
let currentUrlType = null;
let currentVehiclePlate = null;
let activePreset = null;

// CRITICAL: Store separate audio contexts for each vehicle
let vehicleAudioSystems = {}; // Format: { plate: { audioContext, audioElement, sourceNode, eqFilters, gainNode, youtubePlayer } }

// 10-Band EQ Configuration
const EQ_BANDS = [
    { freq: 31, type: 'lowshelf', Q: 1.0 },
    { freq: 62, type: 'peaking', Q: 1.0 },
    { freq: 125, type: 'peaking', Q: 1.0 },
    { freq: 250, type: 'peaking', Q: 1.0 },
    { freq: 500, type: 'peaking', Q: 1.0 },
    { freq: 1000, type: 'peaking', Q: 1.0 },
    { freq: 2000, type: 'peaking', Q: 1.0 },
    { freq: 4000, type: 'peaking', Q: 1.0 },
    { freq: 8000, type: 'peaking', Q: 1.0 },
    { freq: 16000, type: 'highshelf', Q: 1.0 }
];

// Preset management
let vehiclePresets = {}; // Store presets per vehicle
let presetHoldTimer = null;

// Get or create audio system for a specific vehicle
function getVehicleAudioSystem(plate) {
    if (!vehicleAudioSystems[plate]) {
        console.log('Creating new audio system for plate:', plate);
        vehicleAudioSystems[plate] = initWebAudioForVehicle(plate);
    }
    return vehicleAudioSystems[plate];
}

// Cleanup audio for a specific vehicle
function cleanupVehicleAudio(plate) {
    const system = vehicleAudioSystems[plate];
    if (!system) return;
    
    if (system.audioElement) {
        try {
            system.audioElement.pause();
            system.audioElement.src = '';
            system.audioElement.load();
        } catch (e) {}
    }
    
    if (system.youtubePlayer) {
        try {
            system.youtubePlayer.stopVideo();
            system.youtubePlayer.destroy();
        } catch (e) {}
    }
    
    try {
        if (system.sourceNode) system.sourceNode.disconnect();
        for (let filter of system.eqFilters || []) {
            if (filter) filter.disconnect();
        }
        if (system.gainNode) system.gainNode.disconnect();
    } catch (e) {}
    
    if (system.audioContext && system.audioContext.state !== 'closed') {
        try {
            system.audioContext.close();
        } catch (e) {}
    }
    
    delete vehicleAudioSystems[plate];
}

function initWebAudioForVehicle(plate) {
    try {
        const system = {};
        
        system.currentUrl = null;
        system.isPlaying = false;
        
        system.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        
        system.audioElement = document.createElement('audio');
        system.audioElement.crossOrigin = "anonymous";
        system.audioElement.preload = "auto";
        system.audioElement.style.display = 'none';
        system.audioElement.dataset.plate = plate;
        document.body.appendChild(system.audioElement);
        
        system.sourceNode = system.audioContext.createMediaElementSource(system.audioElement);
        system.gainNode = system.audioContext.createGain();
        system.gainNode.gain.value = 1.0;
        
        system.eqFilters = [];
        for (let i = 0; i < EQ_BANDS.length; i++) {
            const filter = system.audioContext.createBiquadFilter();
            filter.type = EQ_BANDS[i].type;
            filter.frequency.value = EQ_BANDS[i].freq;
            filter.Q.value = EQ_BANDS[i].Q;
            filter.gain.value = 0;
            system.eqFilters.push(filter);
        }
        
        let previousNode = system.sourceNode;
        for (let i = 0; i < system.eqFilters.length; i++) {
            previousNode.connect(system.eqFilters[i]);
            previousNode = system.eqFilters[i];
        }
        previousNode.connect(system.gainNode);
        system.gainNode.connect(system.audioContext.destination);
        
        return system;
        
    } catch (error) {
        console.error('Failed to initialize Web Audio for', plate, ':', error);
        return null;
    }
}

function loadYouTubeAPI() {
    if (window.YT) return;
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    const firstScriptTag = document.getElementsByTagName('script')[0];
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
}

window.onYouTubeIframeAPIReady = function() {
    console.log('YouTube IFrame API ready');
};

function createYouTubePlayerForVehicle(plate, videoId, volume, timestamp) {
    const system = getVehicleAudioSystem(plate);
    if (!system) return;
    
    if (system.youtubePlayer) {
        try {
            system.youtubePlayer.destroy();
        } catch (e) {}
    }
    
    const containerId = 'youtube-player-' + plate.replace(/[^a-zA-Z0-9]/g, '');
    let container = document.getElementById(containerId);
    
    if (!container) {
        container = document.createElement('div');
        container.id = containerId;
        container.style.display = 'none';
        document.body.appendChild(container);
    }
    
    system.youtubePlayer = new YT.Player(containerId, {
        height: '0',
        width: '0',
        videoId: videoId,
        playerVars: {
            autoplay: 1,
            controls: 0,
            disablekb: 1,
            fs: 0,
            modestbranding: 1,
            playsinline: 1
        },
        events: {
            onReady: (event) => {
                event.target.setVolume(volume * 100);
                
                if (timestamp && timestamp > 0) {
                    event.target.seekTo(timestamp, true);
                }
                
                event.target.playVideo();
            },
            onStateChange: (event) => {
                if (event.data === YT.PlayerState.ENDED) {
                    // Handle end
                }
            }
        }
    });
}

function extractVideoId(url) {
    const patterns = [
        /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
        /youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})/
    ];
    for (const pattern of patterns) {
        const match = url.match(pattern);
        if (match && match[1]) return match[1];
    }
    return null;
}

function isDirectAudioUrl(url) {
    const audioExtensions = ['.mp3', '.ogg', '.wav', '.m4a', '.aac', '.flac'];
    const lowerUrl = url.toLowerCase();
    return audioExtensions.some(ext => lowerUrl.includes(ext));
}

function determineUrlType(url) {
    if (extractVideoId(url)) {
        return 'youtube';
    } else if (isDirectAudioUrl(url)) {
        return 'direct';
    }
    return 'unknown';
}

function updateStatus(status, text) {
    const dot = document.getElementById('statusDot');
    const txt = document.getElementById('statusText');
    if (dot && txt) {
        dot.className = 'status-dot ' + status;
        txt.textContent = text;
    }
}

function fetchVideoInfo(identifier) {
    // Placeholder - implement if you have video info API
    const titleElement = document.getElementById('videoTitle');
    if (titleElement) {
        titleElement.textContent = 'Playing...';
    }
}

function startProgressUpdate() {
    stopProgressUpdate();
    // Implement progress tracking if needed
}

function stopProgressUpdate() {
    if (updateInterval) {
        clearInterval(updateInterval);
        updateInterval = null;
    }
}

function startEqualizer() {
    stopEqualizer();
    // Implement EQ visualization if needed
}

function stopEqualizer() {
    if (equalizerInterval) {
        clearInterval(equalizerInterval);
        equalizerInterval = null;
    }
}

function applyEQ(values) {
    if (!currentVehiclePlate) return;
    
    const system = getVehicleAudioSystem(currentVehiclePlate);
    if (!system || !system.eqFilters) return;
    
    for (let i = 0; i < Math.min(values.length, system.eqFilters.length); i++) {
        if (system.eqFilters[i]) {
            system.eqFilters[i].gain.value = values[i];
        }
    }
    
    // Update UI sliders
    document.querySelectorAll('.eq-slider').forEach((slider, index) => {
        if (index < values.length) {
            slider.value = values[index];
            const valueDisplay = slider.parentElement.querySelector('.eq-value');
            if (valueDisplay) {
                valueDisplay.textContent = values[index].toFixed(1);
            }
        }
    });
}

function updateEQStatus() {
    const statusText = document.getElementById('eqStatusText');
    if (statusText) {
        if (currentUrlType === 'direct') {
            statusText.innerHTML = '<i class="fas fa-check-circle"></i> EQ Active - Processing audio';
        } else {
            statusText.innerHTML = 'Use ONLY .mp3/.wav/.ogg URLs for real-time eq processing';
        }
    }
}

function renderSavedMusic() {
    const list = document.getElementById('savedMusicList');
    if (!list) return;
    
    if (!savedMusicData || savedMusicData.length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-music"></i>
                <p>No saved music</p>
            </div>
        `;
        return;
    }
    
    list.innerHTML = savedMusicData.map(item => `
        <div class="saved-item" data-id="${item.id}" data-url="${item.url}">
            <div class="saved-item-info">
                <div class="saved-item-name">${item.name}</div>
                <div class="saved-item-url">${item.url.substring(0, 50)}...</div>
            </div>
            <button class="delete-saved-btn" data-id="${item.id}">
                <i class="fas fa-trash"></i>
            </button>
        </div>
    `).join('');
    
    // Add click handlers
    document.querySelectorAll('.saved-item').forEach(item => {
        item.addEventListener('click', function(e) {
            if (e.target.closest('.delete-saved-btn')) return;
            const url = this.dataset.url;
            document.getElementById('youtubeUrl').value = url;
            document.querySelector('[data-tab="player"]').click();
        });
    });
    
    document.querySelectorAll('.delete-saved-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const id = this.dataset.id;
            fetch(`https://${GetParentResourceName()}/deleteMusic`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id: parseInt(id) })
            });
        });
    });
}

// DOM Event Listeners
document.addEventListener('DOMContentLoaded', function() {
    loadYouTubeAPI();
    
    // Close button
    document.getElementById('closeBtn').addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    });
    
    // Play/Pause button
    document.getElementById('playPauseBtn').addEventListener('click', function() {
        const url = document.getElementById('youtubeUrl').value.trim();
        const volume = parseInt(document.getElementById('volumeSlider').value);
        
        if (!isPlaying) {
            if (!url) {
                alert('Please enter a URL');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/play`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url, volume })
            });
            
            isPlaying = true;
            document.getElementById('playPauseIcon').className = 'fas fa-pause';
            updateStatus('online', 'Playing');
        } else {
            fetch(`https://${GetParentResourceName()}/pause`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ timestamp: 0 })
            });
            
            isPlaying = false;
            document.getElementById('playPauseIcon').className = 'fas fa-play';
            updateStatus('paused', 'Paused');
        }
    });
    
    // Stop button
    document.getElementById('stopBtn').addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/stop`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        
        isPlaying = false;
        document.getElementById('playPauseIcon').className = 'fas fa-play';
        updateStatus('offline', 'Stopped');
        document.getElementById('youtubeUrl').value = '';
    });
    
    // Volume slider
    document.getElementById('volumeSlider').addEventListener('input', function() {
        const volume = parseInt(this.value);
        document.getElementById('volumeValue').textContent = volume + '%';
        
        // Send volume update to server for sync
        fetch(`https://${GetParentResourceName()}/updateVolume`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ volume })
        });
    });
    
    // EQ sliders
    document.querySelectorAll('.eq-slider').forEach(slider => {
        slider.addEventListener('input', function() {
            const value = parseFloat(this.value);
            const valueDisplay = this.parentElement.querySelector('.eq-value');
            if (valueDisplay) {
                valueDisplay.textContent = value.toFixed(1);
            }
            
            // Collect all EQ values
            const eqValues = Array.from(document.querySelectorAll('.eq-slider')).map(s => parseFloat(s.value));
            
            // Apply locally
            applyEQ(eqValues);
            
            // Send to server for sync
            fetch(`https://${GetParentResourceName()}/updateEQ`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ eq: eqValues })
            });
        });
    });
    
    // Reset EQ button
    document.getElementById('resetEqBtn').addEventListener('click', function() {
        const zeros = new Array(10).fill(0);
        applyEQ(zeros);
        
        fetch(`https://${GetParentResourceName()}/updateEQ`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ eq: zeros })
        });
    });
    
    // Preset buttons
    document.querySelectorAll('.preset-btn').forEach(btn => {
        let holdTimer = null;
        
        btn.addEventListener('mousedown', function() {
            const slot = parseInt(this.dataset.slot);
            
            holdTimer = setTimeout(() => {
                // Hold to save
                const eqValues = Array.from(document.querySelectorAll('.eq-slider')).map(s => parseFloat(s.value));
                
                fetch(`https://${GetParentResourceName()}/savePreset`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ slot, values: eqValues })
                });
                
                this.classList.add('active');
                activePreset = slot;
            }, 1000);
        });
        
        btn.addEventListener('mouseup', function() {
            if (holdTimer) {
                clearTimeout(holdTimer);
                holdTimer = null;
                
                // Quick click to load
                const slot = parseInt(this.dataset.slot);
                fetch(`https://${GetParentResourceName()}/loadPreset`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ slot })
                });
            }
        });
        
        btn.addEventListener('mouseleave', function() {
            if (holdTimer) {
                clearTimeout(holdTimer);
                holdTimer = null;
            }
        });
    });
    
    // Save music button
    const saveMusicBtn = document.getElementById('saveMusicBtn');
    const saveMusicModal = document.getElementById('saveMusicModal');
    const musicNameInput = document.getElementById('musicNameInput');
    const cancelSaveBtn = document.getElementById('cancelSaveBtn');
    const confirmSaveBtn = document.getElementById('confirmSaveBtn');
    
    saveMusicBtn.onclick = () => {
        const url = document.getElementById('youtubeUrl').value.trim();
        if (!url) {
            alert('Please enter a URL first');
            return;
        }
        musicNameInput.value = '';
        saveMusicModal.classList.remove('hidden');
        musicNameInput.focus();
    };
    
    cancelSaveBtn.onclick = () => {
        saveMusicModal.classList.add('hidden');
    };
    
    confirmSaveBtn.onclick = () => {
        const name = musicNameInput.value.trim();
        const url = document.getElementById('youtubeUrl').value.trim();
        
        if (name && url) {
            fetch(`https://${GetParentResourceName()}/saveMusic`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, url })
            });
            saveMusicModal.classList.add('hidden');
        }
    };
    
    musicNameInput.onkeypress = (e) => {
        if (e.key === 'Enter') confirmSaveBtn.click();
    };
    
    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            
            this.classList.add('active');
            
            const tabId = this.getAttribute('data-tab');
            const contentId = tabId + '-tab';
            document.getElementById(contentId).classList.add('active');
            
            if (tabId === 'equalizer') {
                startEqualizer();
            } else {
                stopEqualizer();
            }
            
            updateEQStatus();
            
            if (tabId === 'saved') {
                renderSavedMusic();
            }
        });
    });
});

// NUI Message Handlers
window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.action === 'open') {
        console.log('=== RADIO OPENED ===');
        document.getElementById('radio-container').classList.remove('hidden');
        isAdvanced = true;
        
        // Store vehicle plate
        if (data.plate) {
            currentVehiclePlate = data.plate;
            console.log('Current vehicle plate:', currentVehiclePlate);
            
            // Initialize audio system for this vehicle
            getVehicleAudioSystem(currentVehiclePlate);
        }
        
        if (data.data) {
            if (data.data.url) {
                document.getElementById('youtubeUrl').value = data.data.url;
                currentUrlType = determineUrlType(data.data.url);
                const identifier = currentUrlType === 'youtube' ? extractVideoId(data.data.url) : data.data.url;
                if (identifier) fetchVideoInfo(identifier);
            }
            if (data.data.volume !== undefined) {
                document.getElementById('volumeSlider').value = data.data.volume;
                document.getElementById('volumeValue').textContent = data.data.volume + '%';
            }
            if (data.data.playing) {
                isPlaying = true;
                document.getElementById('playPauseIcon').className = 'fas fa-pause';
                updateStatus('online', 'Playing');
                startProgressUpdate();
                startEqualizer();
            }
            if (data.data.eq && Array.isArray(data.data.eq)) {
                applyEQ(data.data.eq);
            }
        }
        if (data.savedMusic) {
            savedMusicData = data.savedMusic;
        }
    } else if (data.action === 'close') {
        document.getElementById('radio-container').classList.add('hidden');
        stopProgressUpdate();
        stopEqualizer();
    } else if (data.action === 'updateSavedMusic') {
        savedMusicData = data.savedMusic || [];
        renderSavedMusic();
    } else if (data.action === 'playAdvancedAudio') {
        const plate = data.plate;
        if (!plate) return;
        
        const system = getVehicleAudioSystem(plate);
        if (!system) return;
        
        const urlType = determineUrlType(data.url);
        const timestamp = data.timestamp || 0;
        
        if (system.currentUrl === data.url && system.isPlaying) {
            if (urlType === 'youtube' && system.youtubePlayer) {
                try {
                    system.youtubePlayer.setVolume(data.volume * 100);
                } catch (e) {}
            } else if (urlType === 'direct' && system.gainNode) {
                system.gainNode.gain.value = data.volume;
            }
            return;
        }
        
        system.currentUrl = data.url;
        system.isPlaying = true;
        
        if (urlType === 'direct') {
            playDirectAudioForVehicle(plate, data.url, data.volume, timestamp);
        } else if (urlType === 'youtube') {
            const videoId = extractVideoId(data.url);
            if (videoId && window.YT) {
                createYouTubePlayerForVehicle(plate, videoId, data.volume, timestamp);
            }
        }
    } else if (data.action === 'stopAdvancedAudio') {
        const plate = data.plate;
        if (!plate) return;
        
        const system = vehicleAudioSystems[plate];
        if (system) {
            system.isPlaying = false;
            system.currentUrl = null;
        }
        
        cleanupVehicleAudio(plate);
    } else if (data.action === 'pauseAdvancedAudio') {
        const plate = data.plate;
        if (!plate) return;
        
        const system = vehicleAudioSystems[plate];
        if (!system) return;
        
        if (system.youtubePlayer) {
            try {
                system.youtubePlayer.pauseVideo();
            } catch (e) {}
        } else if (system.audioElement) {
            system.audioElement.pause();
        }
    } else if (data.action === 'resumeAdvancedAudio') {
        const plate = data.plate;
        if (!plate) return;
        
        const system = vehicleAudioSystems[plate];
        if (!system) return;
        
        if (system.youtubePlayer) {
            try {
                system.youtubePlayer.playVideo();
            } catch (e) {}
        } else if (system.audioElement) {
            system.audioElement.play();
        }
    } else if (data.action === 'updateAdvancedDistance') {
        const plate = data.plate;
        if (!plate) return;
        
        const system = vehicleAudioSystems[plate];
        if (!system) return;
        
        if (system.youtubePlayer) {
            try {
                const ytVolume = Math.round(data.volume * 100);
                system.youtubePlayer.setVolume(ytVolume);
            } catch (e) {
                console.error('Error setting YouTube volume:', e);
            }
        } else if (system.gainNode && system.audioElement) {
            system.gainNode.gain.value = data.volume;
        }
    } else if (data.action === 'setEQ') {
        const plate = data.plate;
        if (!plate || !data.eq || !Array.isArray(data.eq)) return;
        
        const applyEQToVehicle = (retries = 0) => {
            const system = vehicleAudioSystems[plate];
            
            if (!system || !system.eqFilters || system.eqFilters.length === 0) {
                if (retries < 5) {
                    setTimeout(() => applyEQToVehicle(retries + 1), 200);
                }
                return;
            }
            
            for (let i = 0; i < Math.min(data.eq.length, system.eqFilters.length); i++) {
                if (system.eqFilters[i]) {
                    system.eqFilters[i].gain.value = data.eq[i];
                }
            }
        };
        
        applyEQToVehicle();
    } else if (data.action === 'updateEQUI') {
        if (data.eq && Array.isArray(data.eq)) {
            document.querySelectorAll('.eq-slider').forEach((slider, index) => {
                if (index < data.eq.length) {
                    slider.value = data.eq[index];
                    const valueDisplay = slider.parentElement.querySelector('.eq-value');
                    if (valueDisplay) {
                        valueDisplay.textContent = data.eq[index].toFixed(1);
                    }
                }
            });
        }
    } else if (data.action === 'loadedPreset') {
        if (data.values && Array.isArray(data.values)) {
            applyEQ(data.values);
            activePreset = data.slot;
            
            document.querySelectorAll('.preset-btn').forEach(btn => btn.classList.remove('active'));
            const btn = document.querySelector(`.preset-btn[data-slot="${data.slot}"]`);
            if (btn) btn.classList.add('active');
            
            if (currentVehiclePlate) {
                if (!vehiclePresets[currentVehiclePlate]) {
                    vehiclePresets[currentVehiclePlate] = {};
                }
                vehiclePresets[currentVehiclePlate][data.slot] = data.values;
            }
        }
    } else if (data.action === 'updateUI') {
        // Update UI when synced from server
        if (data.data) {
            if (data.data.volume !== undefined) {
                document.getElementById('volumeSlider').value = data.data.volume;
                document.getElementById('volumeValue').textContent = data.data.volume + '%';
            }
            if (data.data.playing !== undefined) {
                isPlaying = data.data.playing;
                document.getElementById('playPauseIcon').className = data.data.playing ? 'fas fa-pause' : 'fas fa-play';
                updateStatus(data.data.playing ? 'online' : 'paused', data.data.playing ? 'Playing' : 'Paused');
            }
        }
    }
});

function playDirectAudioForVehicle(plate, url, volume, timestamp) {
    const system = vehicleAudioSystems[plate];
    if (!system || !system.audioElement || !system.audioContext) return;
    
    try {
        try {
            system.sourceNode.disconnect();
            for (let filter of system.eqFilters) filter.disconnect();
            system.gainNode.disconnect();
        } catch (e) {}
        
        let previousNode = system.sourceNode;
        for (let i = 0; i < system.eqFilters.length; i++) {
            previousNode.connect(system.eqFilters[i]);
            previousNode = system.eqFilters[i];
        }
        previousNode.connect(system.gainNode);
        system.gainNode.connect(system.audioContext.destination);
    } catch (e) {
        console.error('Error reconnecting audio chain:', e);
    }
    
    system.audioElement.src = url;
    system.gainNode.gain.value = volume;
    
    const attemptPlay = () => {
        system.audioElement.play().then(() => {
            if (timestamp && timestamp > 0) {
                system.audioElement.currentTime = timestamp;
            }
        }).catch(err => {
            console.error('Play failed:', err);
        });
    };
    
    if (system.audioContext.state === 'suspended') {
        system.audioContext.resume().then(() => {
            attemptPlay();
        }).catch(err => {
            console.error('Resume failed:', err);
        });
    } else {
        attemptPlay();
    }
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const modal = document.getElementById('saveMusicModal');
        if (!modal.classList.contains('hidden')) {
            modal.classList.add('hidden');
        } else {
            const container = document.getElementById('radio-container');
            if (!container.classList.contains('hidden')) {
                document.getElementById('closeBtn').click();
            }
        }
    }
});

function GetParentResourceName() {
    return 'qb-carradio';
}
