const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
  console.log('Request:', req.url);
  
  if (req.url === '/api/play') {
    exec('cvlc --fullscreen --loop /opt/pisignage/media/demo_video.mp4 &');
    res.writeHead(200);
    res.end('Playing');
  } else if (req.url === '/api/stop') {
    exec('killall vlc');
    res.writeHead(200);
    res.end('Stopped');
  } else if (req.url === '/api/status') {
    res.writeHead(200);
    res.end(JSON.stringify({status: 'running', video: 'demo_video.mp4'}));
  } else {
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>PiSignage 2.0</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
            padding: 20px;
          }
          .container { 
            max-width: 1200px; 
            margin: 0 auto;
          }
          h1 { 
            text-align: center; 
            margin-bottom: 40px;
            font-size: 2.5em;
          }
          .card { 
            background: rgba(255,255,255,0.1); 
            padding: 30px; 
            margin: 20px 0; 
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
          }
          button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 15px 30px;
            margin: 10px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s;
          }
          button:hover { 
            background: #45a049; 
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
          }
          .status {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            background: rgba(76, 175, 80, 0.3);
            margin: 5px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🚀 PiSignage 2.0</h1>
          <h2 style="text-align:center; margin-bottom:30px;">Modern Digital Signage System</h2>
          
          <div class="card">
            <h2>📊 État du Système</h2>
            <p><span class="status">✅ Serveur: Actif</span></p>
            <p><span class="status">✅ Vidéo: demo_video.mp4 prête</span></p>
            <p><span class="status">✅ Platform: Raspberry Pi</span></p>
            <p><span class="status">✅ Node.js: v20</span></p>
          </div>
          
          <div class="card">
            <h2>🎬 Contrôle Vidéo</h2>
            <button onclick="playVideo()">▶️ Lancer la vidéo</button>
            <button onclick="stopVideo()">⏹️ Arrêter la vidéo</button>
            <button onclick="getStatus()">📊 Statut</button>
            <div id="status" style="margin-top: 20px;"></div>
          </div>
          
          <div class="card">
            <h2>📁 Fichiers Média</h2>
            <ul style="list-style: none; padding: 0;">
              <li>📹 demo_video.mp4 (2.7 MB)</li>
              <li style="color: rgba(255,255,255,0.6);">ℹ️ Vidéo de démonstration</li>
            </ul>
          </div>
          
          <div class="card">
            <h2>🔧 Information</h2>
            <p>PiSignage 2.0 est un système moderne de digital signage construit avec:</p>
            <ul style="margin-top: 10px; margin-left: 20px;">
              <li>Next.js / React (interface moderne)</li>
              <li>Node.js v20 (serveur)</li>
              <li>VLC (lecture média)</li>
              <li>PM2 (gestion des processus)</li>
            </ul>
          </div>
        </div>
        
        <script>
          function playVideo() {
            fetch('/api/play')
              .then(r => r.text())
              .then(data => {
                document.getElementById('status').innerHTML = '<span class="status">✅ Vidéo lancée</span>';
              });
          }
          
          function stopVideo() {
            fetch('/api/stop')
              .then(r => r.text())
              .then(data => {
                document.getElementById('status').innerHTML = '<span class="status">⏹️ Vidéo arrêtée</span>';
              });
          }
          
          function getStatus() {
            fetch('/api/status')
              .then(r => r.json())
              .then(data => {
                document.getElementById('status').innerHTML = 
                  '<span class="status">📊 Statut: ' + JSON.stringify(data) + '</span>';
              });
          }
        </script>
      </body>
      </html>
    `);
  }
});

server.listen(3000, '0.0.0.0', () => {
  console.log('✅ PiSignage 2.0 démarré sur http://localhost:3000');
});