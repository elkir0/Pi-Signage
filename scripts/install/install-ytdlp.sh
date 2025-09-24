#!/bin/bash

echo "🎬 Installation de yt-dlp pour PiSignage..."

# Install Python3 pip if not present
if ! command -v pip3 &> /dev/null; then
    echo "📦 Installation de pip3..."
    sudo apt-get update
    sudo apt-get install -y python3-pip
fi

# Install yt-dlp via pip
echo "📥 Installation de yt-dlp..."
sudo pip3 install --upgrade yt-dlp

# Alternative: Install from binary
if ! command -v yt-dlp &> /dev/null; then
    echo "💾 Installation depuis le binaire..."
    sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
fi

# Install ffmpeg for video processing
if ! command -v ffmpeg &> /dev/null; then
    echo "🎥 Installation de ffmpeg..."
    sudo apt-get install -y ffmpeg
fi

# Create download directory
sudo mkdir -p /opt/pisignage/media/youtube
sudo chown www-data:www-data /opt/pisignage/media/youtube

# Test installation
echo "✅ Test de l'installation..."
yt-dlp --version

echo "✅ yt-dlp installé avec succès!"
echo "📁 Dossier de téléchargement: /opt/pisignage/media/youtube"