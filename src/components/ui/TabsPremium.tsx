'use client';

import React from 'react';
import { 
  Home, FileVideo, Image, Youtube, Calendar, Activity, Settings,
  PlayCircle, Layers, Monitor, Sliders, Clock, BarChart
} from 'lucide-react';

interface TabData {
  id: string;
  label: string;
  icon: React.ComponentType<any>;
  description?: string;
  badge?: string | number;
  color: string;
}

const TABS_DATA: TabData[] = [
  { 
    id: 'dashboard', 
    label: 'Dashboard', 
    icon: Home, 
    description: 'Centre de contrôle',
    color: 'from-ruby to-crimson'
  },
  { 
    id: 'playlist', 
    label: 'Playlists', 
    icon: Layers, 
    description: 'Gestion des listes',
    badge: 3,
    color: 'from-sapphire to-indigo-600'
  },
  { 
    id: 'media', 
    label: 'Médias', 
    icon: Image, 
    description: 'Bibliothèque',
    badge: 42,
    color: 'from-emerald to-teal-500'
  },
  { 
    id: 'youtube', 
    label: 'YouTube', 
    icon: Youtube, 
    description: 'Téléchargement',
    color: 'from-red-600 to-pink-600'
  },
  { 
    id: 'schedule', 
    label: 'Programmation', 
    icon: Calendar, 
    description: 'Planification',
    badge: 'NEW',
    color: 'from-amber to-orange-600'
  },
  { 
    id: 'monitor', 
    label: 'Monitoring', 
    icon: Activity, 
    description: 'Surveillance',
    color: 'from-purple-600 to-pink-600'
  },
  { 
    id: 'settings', 
    label: 'Paramètres', 
    icon: Settings, 
    description: 'Configuration',
    color: 'from-gray-600 to-gray-500'
  }
];

interface TabsPremiumProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

export default function TabsPremium({ activeTab, onTabChange }: TabsPremiumProps) {
  return (
    <div className="px-6 py-4">
      {/* Navigation principale */}
      <nav className="relative">
        {/* Background blur */}
        <div className="absolute inset-0 bg-gradient-to-r from-obsidian/50 to-charcoal/50 rounded-2xl backdrop-blur-xl" />
        
        {/* Tabs container */}
        <div className="relative grid grid-cols-7 gap-2 p-2">
          {TABS_DATA.map((tab, index) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            
            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={`
                  group relative overflow-hidden rounded-xl transition-all duration-300
                  ${isActive 
                    ? 'bg-gradient-to-br ' + tab.color + ' shadow-lg scale-105' 
                    : 'bg-white/5 hover:bg-white/10'
                  }
                `}
                style={{
                  animationDelay: `${index * 50}ms`
                }}
              >
                {/* Shimmer effect on hover */}
                <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent animate-shimmer" />
                </div>
                
                {/* Content */}
                <div className="relative px-4 py-3 flex flex-col items-center space-y-1">
                  {/* Badge */}
                  {tab.badge && (
                    <span className={`
                      absolute -top-1 -right-1 px-2 py-0.5 text-xs font-bold rounded-full
                      ${typeof tab.badge === 'string' 
                        ? 'bg-gradient-to-r from-amber to-orange-600 text-white' 
                        : 'bg-ruby text-white'
                      }
                      shadow-lg animate-pulse
                    `}>
                      {tab.badge}
                    </span>
                  )}
                  
                  {/* Icon avec effet 3D */}
                  <div className={`
                    p-2 rounded-lg transition-all duration-300
                    ${isActive 
                      ? 'bg-white/20 shadow-inner' 
                      : 'bg-white/5 group-hover:bg-white/10'
                    }
                  `}>
                    <Icon className={`
                      w-5 h-5 transition-all duration-300
                      ${isActive 
                        ? 'text-white drop-shadow-lg' 
                        : 'text-gray-400 group-hover:text-white'
                      }
                      group-hover:scale-110 group-hover:rotate-3
                    `} />
                  </div>
                  
                  {/* Label */}
                  <span className={`
                    text-xs font-semibold transition-all duration-300
                    ${isActive 
                      ? 'text-white' 
                      : 'text-gray-400 group-hover:text-white'
                    }
                  `}>
                    {tab.label}
                  </span>
                  
                  {/* Description (visible on hover) */}
                  <span className={`
                    absolute -bottom-6 left-1/2 -translate-x-1/2 
                    text-xs text-gray-400 whitespace-nowrap
                    opacity-0 group-hover:opacity-100 transition-all duration-300
                    ${isActive ? 'translate-y-0' : 'translate-y-2'}
                  `}>
                    {tab.description}
                  </span>
                </div>
                
                {/* Active indicator */}
                {isActive && (
                  <>
                    <div className="absolute bottom-0 left-1/4 right-1/4 h-1 bg-white/50 rounded-full blur-sm" />
                    <div className="absolute -bottom-px left-1/3 right-1/3 h-0.5 bg-white rounded-full" />
                  </>
                )}
                
                {/* Glow effect for active tab */}
                {isActive && (
                  <div className={`
                    absolute inset-0 rounded-xl opacity-30
                    bg-gradient-to-t ${tab.color} blur-xl
                  `} />
                )}
              </button>
            );
          })}
        </div>
        
        {/* Animated border */}
        <div className="absolute bottom-0 left-0 right-0 h-px">
          <div className="h-full bg-gradient-to-r from-transparent via-ruby/50 to-transparent" />
        </div>
      </nav>
      
      {/* Breadcrumb / Status bar */}
      <div className="mt-4 flex items-center justify-between">
        <div className="flex items-center space-x-2 text-sm">
          <span className="text-gray-500">Vous êtes ici:</span>
          <span className="text-gray-400">/</span>
          <span className="text-ruby font-semibold">
            {TABS_DATA.find(t => t.id === activeTab)?.label}
          </span>
        </div>
        
        <div className="flex items-center space-x-4 text-xs">
          <span className="flex items-center gap-1 text-emerald">
            <span className="w-2 h-2 bg-emerald rounded-full animate-pulse"></span>
            Tous les systèmes opérationnels
          </span>
          <span className="text-gray-500">
            Dernière mise à jour: il y a 2 min
          </span>
        </div>
      </div>
    </div>
  );
}