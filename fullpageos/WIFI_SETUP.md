# 📡 Configuration WiFi pour FullPageOS

## 🔍 Identifier votre version

FullPageOS utilise **2 méthodes** selon la version :

### Version récente (2023+) → NetworkManager
Fichier : `/boot/wifi.nmconnection` ou `/boot/firmware/wifi.nmconnection`

### Version ancienne → WPA Supplicant  
Fichier : `/boot/fullpageos-wpa-supplicant.txt`

## ⚡ Méthode 1 : NetworkManager (RECOMMANDÉ)

### Créer le fichier wifi.nmconnection

Sur votre PC, **AVANT de flasher** ou sur la carte SD après flash :

```ini
[connection]
id=WiFi
uuid=e56bf8e2-3d4f-4b8e-9f3a-8c5d60b81412
type=wifi
autoconnect=true
interface-name=wlan0

[wifi]
mode=infrastructure
ssid=NOM_DE_VOTRE_WIFI

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=VOTRE_MOT_DE_PASSE

[ipv4]
method=auto

[ipv6]
method=auto
```

### ⚠️ IMPORTANT
- Remplacez `NOM_DE_VOTRE_WIFI` par votre SSID
- Remplacez `VOTRE_MOT_DE_PASSE` par votre mot de passe WiFi
- L'UUID peut rester tel quel

### Où placer le fichier

1. **Sur Windows/Mac/Linux** (après flash) :
   ```
   /boot/wifi.nmconnection
   ```
   ou
   ```
   /boot/firmware/wifi.nmconnection
   ```

2. **Permissions** (si vous créez sur Linux) :
   ```bash
   chmod 600 wifi.nmconnection
   ```

## 📝 Méthode 2 : WPA Supplicant (ancien)

Si votre version utilise `fullpageos-wpa-supplicant.txt` :

```bash
update_config=1
country=FR

network={
    ssid="NOM_DE_VOTRE_WIFI"
    psk="VOTRE_MOT_DE_PASSE"
    key_mgmt=WPA-PSK
}
```

## 🔧 Configuration avec Raspberry Pi Imager

Le plus simple est d'utiliser **Raspberry Pi Imager** :

1. Ouvrir Raspberry Pi Imager
2. Choisir l'image FullPageOS
3. Cliquer sur ⚙️ (Paramètres)
4. Configurer :
   - Hostname : `pisignage`
   - Username : `pi`
   - Password : `palmer00`
   - **Configure WiFi** : ✅
     - SSID : Votre WiFi
     - Password : Votre mot de passe
     - Country : FR
   - Enable SSH : ✅

## 🛠️ Modifier après installation

Si le Pi est déjà installé, connectez-vous en Ethernet puis :

### Via SSH
```bash
ssh pi@pisignage.local
# ou
ssh pi@192.168.1.xxx

# Éditer la config
sudo nano /etc/NetworkManager/system-connections/WiFi.nmconnection

# Redémarrer NetworkManager
sudo systemctl restart NetworkManager
```

### Via nmcli
```bash
# Lister les WiFi disponibles
sudo nmcli dev wifi list

# Se connecter
sudo nmcli dev wifi connect "SSID" password "MOT_DE_PASSE"

# Vérifier
nmcli con show
```

## 📋 Exemples de configuration

### WiFi simple (WPA2)
```ini
[connection]
id=MaBox
uuid=e56bf8e2-3d4f-4b8e-9f3a-8c5d60b81412
type=wifi
autoconnect=true

[wifi]
ssid=Livebox-1234

[wifi-security]
key-mgmt=wpa-psk
psk=MonMotDePasse123

[ipv4]
method=auto
```

### WiFi entreprise (WPA2-Enterprise)
```ini
[connection]
id=Entreprise
type=wifi

[wifi]
ssid=WiFi-Entreprise

[wifi-security]
key-mgmt=wpa-eap

[802-1x]
eap=peap
identity=utilisateur@entreprise.com
password=motdepasse
phase2-auth=mschapv2

[ipv4]
method=auto
```

### WiFi avec IP fixe
```ini
[connection]
id=WiFi-Fixe
type=wifi

[wifi]
ssid=MonWiFi

[wifi-security]
key-mgmt=wpa-psk
psk=MotDePasse

[ipv4]
method=manual
address1=192.168.1.150/24
gateway=192.168.1.1
dns=8.8.8.8;8.8.4.4;
```

## 🔍 Vérification

### Après redémarrage
```bash
# Vérifier la connexion
ip a show wlan0

# Vérifier le WiFi
iwconfig wlan0

# Ping test
ping -c 4 google.com

# Logs
journalctl -u NetworkManager -n 50
```

## ❌ Dépannage

### Pas de connexion WiFi

1. **Vérifier le fichier** :
   ```bash
   ls -la /boot/wifi.nmconnection
   # ou
   ls -la /boot/firmware/wifi.nmconnection
   ```

2. **Vérifier les permissions** :
   ```bash
   sudo chmod 600 /etc/NetworkManager/system-connections/*.nmconnection
   ```

3. **Redémarrer NetworkManager** :
   ```bash
   sudo systemctl restart NetworkManager
   ```

4. **Scanner les réseaux** :
   ```bash
   sudo iwlist wlan0 scan | grep ESSID
   ```

### Erreur d'authentification

- Vérifier le mot de passe (attention aux caractères spéciaux)
- Vérifier la casse du SSID
- Essayer avec des guillemets simples si caractères spéciaux

### WiFi 5GHz non détecté

Dans `/boot/config.txt` ou `/boot/firmware/config.txt` :
```
dtoverlay=disable-wifi
dtoverlay=disable-bt
# Puis réactiver
#dtoverlay=disable-wifi
```

## 💡 Tips

1. **Toujours garder Ethernet** comme backup
2. **Tester d'abord** avec un hotspot mobile
3. **Éviter les espaces** dans le SSID
4. **Caractères spéciaux** : Utiliser l'encodage hexadécimal si problème

## 📱 Configuration Hotspot Mobile

Pour tester rapidement avec votre téléphone :

```ini
[connection]
id=Hotspot
type=wifi

[wifi]
ssid=iPhone de Jean

[wifi-security]
key-mgmt=wpa-psk
psk=12345678

[ipv4]
method=auto
```

---

✅ **Une fois configuré**, le Pi se connectera automatiquement au WiFi au démarrage !