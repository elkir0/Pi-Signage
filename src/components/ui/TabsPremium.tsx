'use client';

import React from 'react';
import { 
  Home, FileVideo, Image, Youtube, Calendar, Activity, Settings,
  Layers
} from 'lucide-react';

interface TabData {
  id: string;
  label: string;
  icon: React.ComponentType<any>;
  badge?: string | number;
}

const TABS_DATA: TabData[] = [
  { id: 'dashboard', label: 'Dashboard', icon: Home },
  { id: 'playlist', label: 'Playlists', icon: Layers, badge: 3 },
  { id: 'media', label: 'Médias', icon: Image, badge: 42 },
  { id: 'youtube', label: 'YouTube', icon: Youtube },
  { id: 'schedule', label: 'Programme', icon: Calendar },
  { id: 'monitor', label: 'Monitor', icon: Activity },
  { id: 'settings', label: 'Paramètres', icon: Settings }
];

interface TabsPremiumProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

export default function TabsPremium({ activeTab, onTabChange }: TabsPremiumProps) {
  return (
    <nav className="px-6 py-4">
      <div className="ps-tab-list">
        {TABS_DATA.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`
                ps-tab-trigger
                ${isActive ? 'ps-tab-trigger-active' : ''}
                flex items-center gap-2
              `}
            >
              <Icon className="w-4 h-4" />
              <span className="hidden sm:inline">{tab.label}</span>
              <span className="sm:hidden">{tab.label.slice(0, 3)}</span>
              {tab.badge && (
                <span className="ml-1 px-1.5 py-0.5 text-xs bg-red-600 text-white rounded-full">
                  {tab.badge}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
}