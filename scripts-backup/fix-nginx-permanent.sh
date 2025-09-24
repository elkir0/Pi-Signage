#!/bin/bash

# SOLUTION DÉFINITIVE pour nginx qui persiste après reboot

echo "🔧 RÉPARATION PERMANENTE DE NGINX"

# 1. Créer le service qui crée les dossiers AVANT nginx
cat << 'EOF' | sudo tee /etc/systemd/system/nginx-prepare.service
[Unit]
Description=Prepare directories for nginx
Before=nginx.service

[Service]
Type=oneshot
ExecStart=/bin/mkdir -p /var/log/nginx
ExecStart=/bin/touch /var/log/nginx/error.log
ExecStart=/bin/touch /var/log/nginx/access.log
ExecStart=/bin/chown -R www-data:adm /var/log/nginx
ExecStart=/bin/chmod 755 /var/log/nginx
RemainAfterExit=yes

[Install]
RequiredBy=nginx.service
WantedBy=multi-user.target
EOF

# 2. Modifier nginx pour dépendre du service de préparation
sudo systemctl daemon-reload
sudo systemctl enable nginx-prepare.service
sudo systemctl start nginx-prepare.service

# 3. S'assurer que nginx démarre APRÈS la préparation
sudo mkdir -p /etc/systemd/system/nginx.service.d/
cat << 'EOF' | sudo tee /etc/systemd/system/nginx.service.d/override.conf
[Unit]
After=nginx-prepare.service
Wants=nginx-prepare.service

[Service]
Restart=always
RestartSec=5
StartLimitInterval=0
EOF

# 4. Créer aussi un script de fallback dans rc.local
cat << 'EOF' | sudo tee /etc/rc.local
#!/bin/bash
# Fallback pour nginx
mkdir -p /var/log/nginx
touch /var/log/nginx/error.log /var/log/nginx/access.log
chown -R www-data:adm /var/log/nginx
systemctl restart nginx
exit 0
EOF
sudo chmod +x /etc/rc.local

# 5. Activer rc.local au boot
cat << 'EOF' | sudo tee /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable rc-local.service

# 6. Redémarrer tous les services
sudo systemctl daemon-reload
sudo systemctl restart nginx-prepare.service
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "✅ RÉPARATION PERMANENTE APPLIQUÉE !"
echo ""
echo "Nginx va maintenant:"
echo "1. Créer automatiquement /var/log/nginx au boot"
echo "2. Redémarrer automatiquement en cas d'échec"
echo "3. Avoir un fallback via rc.local"
echo ""
echo "Test:"
sudo systemctl status nginx --no-pager | head -10