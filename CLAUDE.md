# 📺 Mémoire de Contexte - PiSignage 2.0 - ÉTAT CRITIQUE

## ⚠️ ÉTAT ACTUEL : INTERFACE PARTIELLEMENT FONCTIONNELLE

**Mise à jour : 21/09/2025 - 18:30**
**Version : 2.0.0-broken**
**Status : ⚠️ PARTIELLEMENT FONCTIONNEL - Nombreuses erreurs**
**URL Production : http://192.168.1.103**
**GitHub : https://github.com/elkir0/Pi-Signage**

## 🚨 PROBLÈMES CRITIQUES ACTUELS

### Erreurs Console Identifiées
1. **Warning data-kantu** : Extra attributes from the server
2. **API Screenshot 400** : `/api/system/screenshot` retourne Bad Request
3. **Interface "TRES TRES MOCHE"** : Le thème dark mode ne s'applique pas correctement
4. **Composants non stylés** : Les tabs et boutons n'ont pas le style FREE.FR

### Ce qui fonctionne ✅
- Next.js démarre sur le port 80
- Page se charge (HTTP 200)
- API `/api/system` retourne des données
- PM2 maintient le process actif

### Ce qui ne fonctionne PAS ❌
- Thème Dark Mode FREE.FR non appliqué correctement
- API Screenshot retourne 400
- Style général "moche" - pas uniforme
- Logo du projet non intégré
- Erreurs console multiples
- Composants mal alignés

## 📋 TODO IMMÉDIAT

### 1. VALIDATION PUPPETEER OBLIGATOIRE
```javascript
// Test COMPLET avec :
- Screenshot analysé visuellement
- Capture de TOUTES les erreurs console
- Vérification du style (fond noir, texte blanc, bordures rouges)
- Validation des APIs
```

### 2. INTÉGRER LE LOGO
- URL : https://github.com/elkir0/Pi-Signage/blob/main/Pi%20signeage.png
- Doit apparaître dans le header
- Remplacer l'icône Monitor actuelle

### 3. RÉPARER LE STYLE
- Forcer `bg-black` sur TOUT
- Texte `text-white` partout
- Bordures `border-red-600`
- Utiliser les classes FREE.FR créées

### 4. CORRIGER LES APIs
```typescript
// /api/system/screenshot doit :
- Accepter POST sans body
- Retourner {success: true, url: string}
- Gérer les erreurs gracieusement
```

## 🔧 ACCÈS SERVEUR

```bash
# SSH
ssh pi@192.168.1.103
password: raspberry

# Logs PM2
sudo pm2 logs pisignage-web --lines 50

# Restart
sudo pm2 restart pisignage-web

# Pull GitHub
cd /opt/pisignage
git pull origin master
```

## 🏗️ Structure Actuelle

### Composants Créés (mais mal stylés)
- `/src/components/dashboard/Dashboard.tsx`
- `/src/components/media/MediaLibrary.tsx`
- `/src/components/youtube/YouTubeDownloader.tsx`
- `/src/components/playlist/PlaylistManager.tsx`
- `/src/components/settings/Settings.tsx`
- `/src/components/schedule/Schedule.tsx`
- `/src/components/monitor/SystemMonitor.tsx`
- `/src/components/ui/custom-tabs.tsx` ← DOIT ÊTRE AMÉLIORÉ

### APIs Créées
- `/api/system` ✅ Fonctionne
- `/api/system/screenshot` ❌ Retourne 400
- `/api/media` ❓ Non testé
- `/api/playlist` ❓ Non testé
- `/api/youtube/download` ❓ Non testé
- `/api/settings` ✅ Corrigé (backupFile)

## 🎨 STYLE ATTENDU (FREE.FR)

### Couleurs OBLIGATOIRES
```css
/* FOND */
background: #000000 (noir pur)

/* TEXTE */
color: #FFFFFF (blanc)

/* ACCENTS */
primary: #DC2626 (rouge FREE.FR)
border: #DC2626 (rouge)

/* HOVER */
hover: #EF4444 (rouge plus clair)
```

### Classes à utiliser
```css
.bg-black
.text-white
.border-red-600
.bg-red-600
.hover:bg-red-700
.shadow-red-600/50
```

## 📊 MÉTRIQUES DE VALIDATION

### Test Puppeteer DOIT vérifier :
1. **Screenshot** : Fond noir visible
2. **Console** : 0 erreurs, 0 warnings
3. **APIs** : Toutes retournent 200
4. **Style** : 
   - `body.backgroundColor === 'rgb(0, 0, 0)'`
   - Au moins 5 éléments avec `border-red-600`
   - Tous les textes en blanc
5. **Logo** : Présent et visible

## ⚡ COMMANDES RAPIDES

```bash
# Test local
npm run dev

# Test Puppeteer
node test-complet.js

# Commit et deploy
git add -A && git commit -m "fix: ..." && git push
ssh pi@192.168.1.103 "cd /opt/pisignage && git pull && sudo pm2 restart pisignage-web"

# Vérifier production
curl -I http://192.168.1.103
```

## 🚫 RÈGLES STRICTES

### NE JAMAIS :
- Dire "ça marche" sans test Puppeteer
- Ignorer les erreurs console
- Déployer sans tester localement d'abord

### TOUJOURS :
- Faire un screenshot Puppeteer
- Analyser TOUTES les erreurs console
- Vérifier le style visuellement
- Tester les APIs une par une

## 📝 PROCHAINES ÉTAPES

1. **URGENT** : Créer `test-complet.js` avec analyse screenshot + console
2. **URGENT** : Télécharger et intégrer le logo
3. **URGENT** : Réparer l'API screenshot
4. **URGENT** : Forcer le style dark sur TOUS les composants
5. Tester avec Puppeteer
6. Déployer SEULEMENT si tests OK

---

*Dernière mise à jour : 21/09/2025 - 18:30*
*État : CRITIQUE - Interface moche et erreurs multiples*