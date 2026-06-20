# 🚀 MCP Quick Reference - Pi-Signage

**Serveur:** `http://localhost:8811` | **Namespace:** `pisignage` | **Mémoires:** 7

---

## 📋 Clés Mémoires Disponibles

| Clé | Description | Taille |
|-----|-------------|--------|
| `ns::pisignage::context` | Vue d'ensemble projet | 704 car. |
| `ns::pisignage::architecture` | Stack technique complet | 1,295 car. |
| `ns::pisignage::config` | Configs, chemins, commandes | 1,679 car. |
| `ns::pisignage::notes` | Décisions techniques, bugs | 2,016 car. |
| `ns::pisignage::tasks` | État dev, commits, PR | 1,525 car. |
| `ns::pisignage::api-endpoints` | Spécifications API REST | 2,238 car. |
| `ns::pisignage::versions-history` | Changelog & roadmap | 1,634 car. |

---

## ⚡ Commandes Rapides

### Rechercher tout sur un sujet
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"VLC","limit":5}' | jq '.memories'
```

### Lister toutes les mémoires
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"limit":20}' | jq -r '.memories[]|.id'
```

### Rechercher par topic
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"topics":{"any":["architecture"]}}' | jq '.'
```

### Créer/Mettre à jour mémoire
```bash
curl -s http://localhost:8811/v1/long-term-memory/ -X POST \
  -H 'Content-Type: application/json' \
  -d '{
    "memories": [{
      "id": "ns::pisignage::nouvelle",
      "text": "Contenu de la mémoire...",
      "namespace": "pisignage",
      "pinned": true,
      "topics": ["topic1", "topic2"]
    }]
  }'
```

---

## 🎯 Cas d'Usage

### 1. Obtenir l'architecture complète
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"architecture"}' | \
  jq -r '.memories[0].text'
```

### 2. Lister tous les endpoints API
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"API endpoints"}' | \
  jq -r '.memories[0].text'
```

### 3. Vérifier l'état des tâches
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"tasks"}' | \
  jq -r '.memories[0].text'
```

### 4. Obtenir historique versions
```bash
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"versions"}' | \
  jq -r '.memories[0].text'
```

---

## 🔄 Workflow de Mise à Jour

### Après merge d'une feature
```bash
# 1. Préparer le nouveau contenu
cat > update_tasks.json << 'EOF'
{
  "memories": [{
    "id": "ns::pisignage::tasks",
    "text": "État développement Pi-Signage (DATE):\n\n**Dernières features:**\n...",
    "namespace": "pisignage",
    "pinned": true,
    "topics": ["development-status", "tasks"]
  }]
}
EOF

# 2. Envoyer la mise à jour
curl -s http://localhost:8811/v1/long-term-memory/ -X POST \
  -H 'Content-Type: application/json' \
  -d @update_tasks.json

# 3. Vérifier
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"text":"tasks"}' | jq '.memories[0].id'
```

---

## 📊 Statistiques Actuelles

- **Total mémoires:** 7
- **Toutes épinglées:** ✅ Oui (protection auto-delete)
- **Taille totale:** ~11,091 caractères
- **Topics couverts:** 21 topics uniques
- **Namespace isolé:** `pisignage`

---

## 🛡️ Sécurité & Maintenance

- ✅ Mémoires épinglées ne sont jamais auto-supprimées
- ✅ Namespace isolé évite les conflits
- ✅ ID stables permettent upsert simple
- ✅ Backup via fichier `MCP_MEMORY_BACKUP.md`

---

## 📱 API Web UI

Swagger documentation complète disponible à :
**http://localhost:8811/docs**

OpenAPI schema JSON :
**http://localhost:8811/openapi.json**

---

## 💡 Tips

1. **Toujours utiliser le namespace `pisignage`**
2. **Préfixer les IDs avec `ns::pisignage::`**
3. **Épingler les mémoires importantes** (`pinned: true`)
4. **Utiliser topics pour catégoriser**
5. **Tester les recherches** avant production

---

## 🆘 Troubleshooting

### Mémoire non trouvée
```bash
# Vérifier namespace et ID
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"}}' | jq '.memories[] | .id'
```

### Serveur non accessible
```bash
# Vérifier santé
curl -s http://localhost:8811/v1/health
# Réponse attendue: {"status":"healthy",...}
```

### Recherche ne retourne rien
```bash
# Utiliser text générique
curl -s http://localhost:8811/v1/long-term-memory/search -X POST \
  -H 'Content-Type: application/json' \
  -d '{"namespace":{"eq":"pisignage"},"limit":20}' | jq '.memories | length'
```

---

**Dernière sync:** 2025-11-09 | **Status:** ✅ Opérationnel
