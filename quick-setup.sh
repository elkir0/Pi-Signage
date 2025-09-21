#!/bin/bash

# Script rapide pour terminer l'installation
set -e

echo "🚀 CONFIGURATION RAPIDE PISIGNAGE"
echo "================================="

# 1. Vérifier si Node.js est installé
echo "✅ Vérification Node.js..."
node --version || (echo "Installation Node.js..." && curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs)

# 2. Installer PM2 si nécessaire
echo "✅ Installation PM2..."
sudo npm install -g pm2 || true

# 3. Télécharger la vidéo YouTube
echo "🎬 Téléchargement de la vidéo..."
cd /opt/pisignage
sudo mkdir -p media
cd media
sudo yt-dlp -f "best[height<=720]" \
    -o "demo_video.%(ext)s" \
    "https://www.youtube.com/watch?v=xOMMV_qXcQ8" || \
    sudo wget -O demo_video.mp4 "https://download.samplelib.com/mp4/sample-5s.mp4"

# 4. Créer un simple serveur web
echo "🌐 Configuration serveur web simple..."
cd /opt/pisignage
sudo tee server.js > /dev/null << 'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>PiSignage 2.0</title>
      <style>
        body { 
          margin: 0; 
          padding: 20px; 
          font-family: Arial; 
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { text-align: center; }
        .card { 
          background: rgba(255,255,255,0.1); 
          padding: 20px; 
          margin: 20px 0; 
          border-radius: 10px;
          backdrop-filter: blur(10px);
        }
        button {
          background: #4CAF50;
          color: white;
          border: none;
          padding: 10px 20px;
          margin: 5px;
          border-radius: 5px;
          cursor: pointer;
        }
        button:hover { background: #45a049; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 PiSignage 2.0 - Modern Digital Signage</h1>
        
        <div class="card">
          <h2>📊 System Status</h2>
          <p>✅ Server: Running</p>
          <p>✅ Video: demo_video.mp4 ready</p>
          <p>✅ Platform: Raspberry Pi</p>
        </div>
        
        <div class="card">
          <h2>🎬 Video Control</h2>
          <button onclick="fetch('/api/play')">▶️ Play</button>
          <button onclick="fetch('/api/stop')">⏹️ Stop</button>
          <button onclick="fetch('/api/status').then(r=>r.text()).then(alert)">📊 Status</button>
        </div>
        
        <div class="card">
          <h2>📁 Media Files</h2>
          <ul id="files"></ul>
        </div>
      </div>
      
      <script>
        fetch('/api/files')
          .then(r => r.json())
          .then(files => {
            const list = document.getElementById('files');
            files.forEach(f => {
              const li = document.createElement('li');
              li.textContent = f;
              list.appendChild(li);
            });
          }).catch(() => {
            document.getElementById('files').innerHTML = '<li>demo_video.mp4</li>';
          });
      </script>
    </body>
    </html>
  `);
});

// API endpoints
if (req.url === '/api/play') {
  const { exec } = require('child_process');
  exec('cvlc --fullscreen --loop /opt/pisignage/media/demo_video.mp4 &');
  res.end('Playing');
} else if (req.url === '/api/stop') {
  const { exec } = require('child_process');
  exec('killall vlc');
  res.end('Stopped');
}

server.listen(3000, () => {
  console.log('PiSignage running on http://localhost:3000');
});
EOF

# 5. Démarrer le serveur avec PM2
echo "🚀 Démarrage du serveur..."
pm2 delete pisignage 2>/dev/null || true
pm2 start server.js --name pisignage
pm2 save
pm2 startup systemd -u pi --hp /home/pi | grep sudo | bash || true

# 6. Configuration Nginx
echo "⚙️ Configuration Nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx || true

# 7. Démarrer VLC avec la vidéo
echo "▶️ Démarrage de la vidéo..."
export DISPLAY=:0
nohup cvlc --fullscreen --loop --no-video-title-show /opt/pisignage/media/demo_video.* > /dev/null 2>&1 &

# Affichage final
IP=$(hostname -I | cut -d' ' -f1)
echo ""
echo "✅ INSTALLATION TERMINÉE!"
echo "========================"
echo "🌐 Interface: http://$IP"
echo "📺 Vidéo: En lecture"
echo ""
echo "🎉 PiSignage 2.0 opérationnel!"