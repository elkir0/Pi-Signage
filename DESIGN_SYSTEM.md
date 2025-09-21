# 🎨 PiSignage Spectacular Design System v2.0

## Vue d'ensemble

Le Design System PiSignage v2.0 transforme l'interface utilisateur avec un design moderne, élégant et spectaculaire tout en conservant l'identité FREE.FR (noir/rouge/blanc). Ce système utilise des gradients subtils, des effets de glassmorphism, des animations fluides et une palette de couleurs étendue.

## 🎨 Palette de Couleurs

### Couleurs Principales

```css
/* Noir & Nuances */
--ps-black: 0 0% 2%           /* Noir profond principal */
--ps-midnight: 220 15% 6%     /* Bleu-noir midnight */
--ps-obsidian: 240 10% 9%     /* Obsidian pour surfaces */
--ps-charcoal: 225 8% 12%     /* Charcoal pour contraste */

/* Accents Rouge FREE.FR */
--ps-crimson: 0 85% 55%       /* Rouge FREE.FR signature */
--ps-ruby: 355 90% 60%        /* Ruby vif pour hover */
--ps-coral: 15 85% 65%        /* Coral moderne pour accents */
--ps-amber: 45 95% 68%        /* Amber doré pour highlights */

/* Surfaces Métalliques */
--ps-slate: 215 20% 15%       /* Slate moderne */
--ps-steel: 210 18% 18%       /* Steel bleu */
--ps-zinc: 225 15% 20%        /* Zinc métallique */
--ps-smoke: 220 12% 25%       /* Smoke subtil */
```

### Couleurs Sémantiques

```css
--ps-success: 142 85% 55%     /* Emerald success */
--ps-warning: 38 95% 65%      /* Orange warning */
--ps-error: 0 90% 65%         /* Red error */
--ps-info: 200 95% 65%        /* Blue info */
```

## 🎭 Composants

### Boutons

```css
/* Bouton Principal */
.ps-btn-primary {
  background: linear-gradient(135deg, hsl(var(--ps-crimson)), hsl(var(--ps-ruby)));
  box-shadow: var(--ps-shadow-md), 0 0 20px hsl(var(--ps-crimson) / 0.3);
}

/* Bouton Secondaire */
.ps-btn-secondary {
  background: var(--ps-glass-bg);
  backdrop-filter: blur(16px);
  border: 1px solid hsl(var(--ps-crimson) / 0.3);
}

/* Bouton Ghost */
.ps-btn-ghost {
  background: transparent;
  color: hsl(var(--ps-text-secondary));
}
```

### Cartes

```css
/* Carte Standard */
.ps-card {
  background: var(--ps-glass-bg);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--ps-radius-xl);
}

/* Carte Élevée */
.ps-card-elevated {
  background: linear-gradient(135deg, 
    hsl(var(--ps-obsidian) / 0.8), 
    hsl(var(--ps-charcoal) / 0.6)
  );
  border: 1px solid hsl(var(--ps-crimson) / 0.2);
}
```

### Inputs

```css
.ps-input {
  background: var(--ps-glass-bg);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--ps-radius-lg);
}

.ps-input:focus {
  border-color: hsl(var(--ps-crimson));
  box-shadow: 0 0 0 1px hsl(var(--ps-crimson)), 0 0 20px hsl(var(--ps-crimson) / 0.3);
}
```

## ✨ Effets et Animations

### Glassmorphism

```css
.ps-glass {
  background: rgba(15, 23, 42, 0.6);
  backdrop-filter: blur(16px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
}
```

### Gradients

```css
/* Gradient Principal */
.ps-gradient-primary {
  background: linear-gradient(135deg, 
    hsl(var(--ps-black)), 
    hsl(var(--ps-midnight)), 
    hsl(var(--ps-obsidian))
  );
}

/* Gradient Texte */
.ps-gradient-text {
  background: linear-gradient(135deg, 
    hsl(var(--ps-crimson)), 
    hsl(var(--ps-ruby)), 
    hsl(var(--ps-amber))
  );
  background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

### Animations

```css
/* Shimmer Effect */
.ps-animate-shimmer {
  animation: shimmer 2s linear infinite;
}

/* Pulse Crimson */
.ps-animate-pulse-crimson {
  animation: pulse-crimson 2s infinite;
}

/* Float Effect */
.ps-animate-float {
  animation: float 3s ease-in-out infinite;
}

/* Fade In */
.ps-animate-fade-in {
  animation: slide-in-up 0.5s cubic-bezier(0.4, 0, 0.2, 1);
}
```

## 🎯 États Interactifs

### Hover Effects

```css
.ps-btn-primary:hover {
  background: linear-gradient(135deg, hsl(var(--ps-ruby)), hsl(var(--ps-coral)));
  box-shadow: var(--ps-shadow-lg), 0 0 30px hsl(var(--ps-crimson) / 0.4);
  transform: translateY(-1px);
}

.ps-card:hover {
  border-color: hsl(var(--ps-crimson) / 0.5);
  box-shadow: var(--ps-shadow-xl), 0 0 40px hsl(var(--ps-crimson) / 0.2);
  transform: translateY(-2px);
}
```

## 📐 Système de Dimensions

### Espacements

```css
--ps-space-xs: 0.25rem    /* 4px */
--ps-space-sm: 0.5rem     /* 8px */
--ps-space-md: 1rem       /* 16px */
--ps-space-lg: 1.5rem     /* 24px */
--ps-space-xl: 2rem       /* 32px */
--ps-space-2xl: 3rem      /* 48px */
--ps-space-3xl: 4rem      /* 64px */
```

### Border Radius

```css
--ps-radius-xs: 0.125rem   /* 2px */
--ps-radius-sm: 0.25rem    /* 4px */
--ps-radius-md: 0.5rem     /* 8px */
--ps-radius-lg: 0.75rem    /* 12px */
--ps-radius-xl: 1rem       /* 16px */
--ps-radius-2xl: 1.5rem    /* 24px */
```

## 🔤 Typographie

### Fonts

```css
/* Primary Font */
font-family: 'Inter', system-ui, sans-serif;

/* Monospace Font */
font-family: 'JetBrains Mono', Monaco, 'Cascadia Code', monospace;
```

### Hiérarchie

```css
h1 { @apply text-4xl lg:text-5xl font-bold tracking-tight; }
h2 { @apply text-3xl lg:text-4xl font-semibold tracking-tight; }
h3 { @apply text-2xl lg:text-3xl font-semibold; }
h4 { @apply text-xl lg:text-2xl font-medium; }
h5 { @apply text-lg lg:text-xl font-medium; }
h6 { @apply text-base lg:text-lg font-medium; }
```

## 📱 Usage Responsive

### Breakpoints

```css
/* Mobile First */
sm: '640px'    /* Tablet portrait */
md: '768px'    /* Tablet landscape */
lg: '1024px'   /* Desktop */
xl: '1280px'   /* Large desktop */
2xl: '1536px'  /* Extra large */
```

## 🛠️ Classes Utilitaires

### Transitions

```css
.transition-smooth {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.transition-bounce {
  transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
}
```

### Performance

```css
.transform-gpu {
  transform: translateZ(0);
  backface-visibility: hidden;
  perspective: 1000px;
}
```

## 🎪 Exemples d'Usage

### Bouton Spectaculaire

```jsx
<button className="ps-btn-primary ps-animate-scale-in">
  <Icon className="w-5 h-5" />
  <span>Action Primaire</span>
</button>
```

### Carte avec Glow

```jsx
<div className="ps-card-elevated ps-glow-crimson p-6">
  <h3 className="ps-gradient-text text-xl font-bold mb-4">Titre</h3>
  <p className="text-white/80">Contenu de la carte...</p>
</div>
```

### Input Moderne

```jsx
<input 
  className="ps-input w-full"
  placeholder="Saisissez votre texte..."
/>
```

### Navigation Tabs

```jsx
<div className="ps-tab-list">
  <button className="ps-tab-trigger ps-tab-trigger-active">
    Actif
  </button>
  <button className="ps-tab-trigger ps-tab-trigger-inactive">
    Inactif
  </button>
</div>
```

## 🎨 Design Principles

1. **Glassmorphism First** - Utiliser les effets de verre pour la profondeur
2. **Gradients Subtils** - Éviter les couleurs plates, préférer les dégradés
3. **Micro-interactions** - Ajouter des animations pour le feedback utilisateur
4. **Contraste Intelligent** - Maintenir une lisibilité parfaite
5. **Performance** - Optimiser avec transform-gpu pour les animations
6. **Cohérence** - Utiliser systématiquement les design tokens

## 🚀 Migration depuis l'ancien système

### Classes Legacy → Nouvelles Classes

```css
/* Ancien */
.btn-free → .ps-btn-primary
.card-free → .ps-card
.input-free → .ps-input
.text-gradient-free → .ps-gradient-text
.glow-red → .ps-glow-crimson

/* Nouvelles classes recommandées */
.ps-card-elevated
.ps-btn-secondary
.ps-btn-ghost
.ps-surface
.ps-glass
```

Ce design system transforme complètement l'apparence de PiSignage en une interface moderne, élégante et professionnelle digne d'un produit premium, tout en conservant l'identité visuelle FREE.FR.