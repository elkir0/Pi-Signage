<?php
// Test VLC detection
$vlcRunning = !empty(trim(shell_exec('pgrep -x vlc 2>/dev/null')));
$ffmpegPath = shell_exec("which ffmpeg 2>/dev/null");

echo "VLC running: " . ($vlcRunning ? 'true' : 'false') . "\n";
echo "FFmpeg path: " . ($ffmpegPath ? trim($ffmpegPath) : 'not found') . "\n";
echo "Combined check: " . (($vlcRunning && $ffmpegPath) ? 'OK' : 'FAIL') . "\n";

// Test pgrep output
$pgrep_output = shell_exec('pgrep -x vlc 2>/dev/null');
echo "Pgrep output: '" . $pgrep_output . "'\n";
echo "Pgrep trimmed: '" . trim($pgrep_output) . "'\n";
echo "Pgrep empty check: " . (empty(trim($pgrep_output)) ? 'empty' : 'not empty') . "\n";
?>