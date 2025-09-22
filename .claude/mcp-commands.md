# = Commandes MCP pour pisignage

## Rechercher dans ce projet uniquement
```javascript
mcp__memory__search_nodes("/opt/pisignage:")
```

## Ouvrir les entités principales
```javascript
mcp__memory__open_nodes([
    "/opt/pisignage:PROJECT",
    "/opt/pisignage:CONFIG",
    "/opt/pisignage:RULES",
    "/opt/pisignage:STATUS",
    "/opt/pisignage:ISSUES"
])
```

## Ajouter une observation
```javascript
mcp__memory__add_observations({
    observations: [{
        entityName: "/opt/pisignage:STATUS",
        contents: ["Nouvelle observation ici"]
    }]
})
```

## Créer une nouvelle entité
```javascript
mcp__memory__create_entities({
    entities: [{
        name: "/opt/pisignage:NOUVELLE_ENTITE",
        entityType: "TYPE",
        observations: ["Description"]
    }]
})
```

##   IMPORTANT
Toujours utiliser le préfixe : /opt/pisignage:
Cela garantit l'isolation entre projets !
