# = Commandes MCP pour pisignage

## Rechercher dans ce projet uniquement
```javascript
mcp__memory__search_nodes("/opt/pisignage:")
```

## Ouvrir les entit�s principales
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

## Cr�er une nouvelle entit�
```javascript
mcp__memory__create_entities({
    entities: [{
        name: "/opt/pisignage:NOUVELLE_ENTITE",
        entityType: "TYPE",
        observations: ["Description"]
    }]
})
```

## � IMPORTANT
Toujours utiliser le pr�fixe : /opt/pisignage:
Cela garantit l'isolation entre projets !
