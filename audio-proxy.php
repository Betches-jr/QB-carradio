<?php
/**
 * Simple Audio CORS Proxy
 * Place this file on your web server
 * Usage: http://yourserver.com/audio-proxy.php?url=AUDIO_URL
 */

// Enable CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Get URL parameter
$url = isset($_GET['url']) ? $_GET['url'] : '';

if (empty($url)) {
    http_response_code(400);
    die('Error: No URL provided. Usage: audio-proxy.php?url=AUDIO_URL');
}

// Validate URL
if (!filter_var($url, FILTER_VALIDATE_URL)) {
    http_response_code(400);
    die('Error: Invalid URL');
}

// Security: Only allow audio files
$allowed_extensions = ['.mp3', '.ogg', '.wav', '.m4a', '.aac', '.flac'];
$has_valid_extension = false;
foreach ($allowed_extensions as $ext) {
    if (stripos($url, $ext) !== false) {
        $has_valid_extension = true;
        break;
    }
}

if (!$has_valid_extension) {
    http_response_code(400);
    die('Error: Only audio files are allowed');
}

// Initialize cURL
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

// Get file info
curl_setopt($ch, CURLOPT_HEADER, true);
curl_setopt($ch, CURLOPT_NOBODY, true);
curl_exec($ch);
$info = curl_getinfo($ch);

// Check if file exists
if ($info['http_code'] !== 200) {
    http_response_code(404);
    curl_close($ch);
    die('Error: Audio file not found or not accessible');
}

// Get content type
$content_type = isset($info['content_type']) ? $info['content_type'] : 'audio/mpeg';

// Re-initialize for actual download
curl_setopt($ch, CURLOPT_HEADER, false);
curl_setopt($ch, CURLOPT_NOBODY, false);

// Stream the audio
header('Content-Type: ' . $content_type);
if (isset($info['download_content_length'])) {
    header('Content-Length: ' . $info['download_content_length']);
}

// Execute and output
$audio = curl_exec($ch);

if (curl_errno($ch)) {
    http_response_code(500);
    echo 'Error: ' . curl_error($ch);
}

curl_close($ch);
?>
