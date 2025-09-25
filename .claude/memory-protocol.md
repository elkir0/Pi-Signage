# Mon Protocole de Gestion Mémoire MCP

## 🎯 Objectif Principal
Maintenir une mémoire MCP propre et efficace avec maximum 10 entrées pertinentes.

## ⚡ AVANT chaque réponse
1. **Vérification rapide** : Compter les entrées MCP
2. **Si > 10 entrées** : Lancer nettoyage immédiat
3. **Charger uniquement** : Les entrées pertinentes pour la tâche

## 💾 APRÈS chaque save
1. **Vérifier la taille totale** : Max 50KB total
2. **Si nouvelle entrée** : Supprimer la plus ancienne non-critique
3. **Règle stricte** : "1 nouveau = 1 ancien supprimé"

## 📋 Mes règles personnelles

### Garder TOUJOURS (max 4)
- `PROJECT:architecture` - Architecture principale du projet
- `RULES:coding` - Règles de développement
- `CURRENT:task` - Tâche en cours
- `GOLDEN:reference` - Références validées

### Rotation QUOTIDIENNE (max 3)
- `STATUS:*` - États temporaires
- `WIP:*` - Travail en cours
- `TEST:*` - Résultats de tests

### Supprimer IMMÉDIATEMENT
- Entrées avec "background_bash"
- Entrées avec "test_report" > 1 jour
- Doublons sémantiques
- Entrées > 15KB

## 🔄 Patterns de fusion automatique
```
GPU_* + CHROMIUM_* → BROWSER_CONFIG
VLC_* + MPV_* → PLAYER_CONFIG
screenshot_* + capture_* → CAPTURE_SYSTEM
install_* + deploy_* → DEPLOYMENT
```

## 📊 Métriques de santé
- **Santé optimale** : ≤ 8 entrées, < 40KB total
- **Attention** : 9-10 entrées, 40-50KB
- **Critique** : > 10 entrées ou > 50KB

## 🤖 Mon agent me rappelle

### Toutes les 10 interactions
```
🧹 Mémoire : X/10 entrées, Y/50 KB
💡 Recommandation : [action suggérée]
```

### Alertes automatiques
- 🔴 **URGENT** : > 15 entrées → Nettoyage forcé
- 🟡 **ATTENTION** : > 10 entrées → Suggestion de fusion
- 🟢 **OPTIMAL** : ≤ 8 entrées → Aucune action

## 🎯 Stratégie de nettoyage

### Phase 1 : Suppression (immédiat)
1. Entrées obsolètes (> 7 jours sans accès)
2. Doublons détectés
3. Entrées temporaires marquées

### Phase 2 : Fusion (5 min)
1. Grouper par thème
2. Fusionner les observations
3. Compacter à 10 observations max

### Phase 3 : Optimisation (10 min)
1. Calculer scores d'importance
2. Garder top 10
3. Archiver le reste

## 🔍 Détection des patterns

### Ce que je sauve trop souvent
- Configurations GPU/Chromium (15+ entrées)
- Rapports de test temporaires
- États de déploiement

### Ce que je dois améliorer
- Utiliser des clés plus courtes
- Fusionner les entrées similaires plus tôt
- Supprimer les temporaires immédiatement

## 📝 Template d'entrée optimale
```json
{
  "name": "PROJECT:nom_court",
  "entityType": "type_simple",
  "observations": [
    "Point clé 1 (max 100 chars)",
    "Point clé 2",
    "...",
    "Max 10 observations"
  ]
}
```

## ⚙️ Configuration auto-nettoyage

### Triggers automatiques
- Après chaque session de 30+ minutes
- Quand total > 50KB
- Quand entrées > 12
- Avant shutdown/sleep

### Actions par défaut
1. Fusionner les similaires
2. Compacter les volumineuses
3. Supprimer les obsolètes
4. Archiver si nécessaire

## 🚀 Commandes rapides
```bash
# Status rapide
python3 .claude/memory-agent.py --status

# Analyse complète
python3 .claude/memory-agent.py --analyze

# Nettoyage intelligent
python3 .claude/memory-agent.py --clean

# Optimisation suggérée
python3 .claude/memory-agent.py --optimize

# Apprentissage adaptatif
python3 .claude/memory-agent.py --learn
```

---

*Ce protocole est auto-adaptatif et apprend de mes patterns d'usage.*