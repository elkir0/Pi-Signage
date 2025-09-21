'use client';

import React, { useState } from 'react';
import HeaderPremium from '@/components/layout/HeaderPremium';
import TabsPremium from '@/components/ui/TabsPremium';
import DashboardPremium from '@/components/dashboard/DashboardPremium';
import MediaLibrary from '@/components/media/MediaLibrary';
import PlaylistManager from '@/components/playlist/PlaylistManager';
import YouTubeDownloader from '@/components/youtube/YouTubeDownloader';
import Schedule from '@/components/schedule/Schedule';
import SystemMonitor from '@/components/monitor/SystemMonitor';
import Settings from '@/components/settings/Settings';

export default function HomePremium() {
  const [activeTab, setActiveTab] = useState('dashboard');

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardPremium />;
      case 'media':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <MediaLibrary />
            </div>
          </div>
        );
      case 'playlist':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <PlaylistManager />
            </div>
          </div>
        );
      case 'youtube':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <YouTubeDownloader />
            </div>
          </div>
        );
      case 'schedule':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <Schedule />
            </div>
          </div>
        );
      case 'monitor':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <SystemMonitor />
            </div>
          </div>
        );
      case 'settings':
        return (
          <div className="p-6 animate-slide-up">
            <div className="glass-card p-6">
              <Settings />
            </div>
          </div>
        );
      default:
        return <DashboardPremium />;
    }
  };

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Mesh Background animé */}
      <div className="mesh-background" />
      
      {/* Particules flottantes (optionnel) */}
      <div className="fixed inset-0 pointer-events-none">
        {[...Array(5)].map((_, i) => (
          <div
            key={i}
            className="absolute w-64 h-64 rounded-full opacity-10"
            style={{
              background: `radial-gradient(circle, ${
                i % 2 === 0 ? 'rgba(220, 38, 38, 0.3)' : 'rgba(59, 130, 246, 0.3)'
              } 0%, transparent 70%)`,
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              animation: `float ${10 + i * 2}s ease-in-out infinite`,
              animationDelay: `${i * 2}s`
            }}
          />
        ))}
      </div>
      
      {/* Contenu principal */}
      <div className="relative z-10">
        {/* Header Premium */}
        <HeaderPremium />
        
        {/* Navigation Premium */}
        <TabsPremium activeTab={activeTab} onTabChange={setActiveTab} />
        
        {/* Zone de contenu avec animation */}
        <main className="container mx-auto">
          <div className="min-h-[calc(100vh-220px)]">
            {renderContent()}
          </div>
        </main>
      </div>
      
      {/* Footer avec gradient */}
      <footer className="relative z-10 mt-auto">
        <div className="h-px bg-gradient-to-r from-transparent via-ruby/30 to-transparent" />
        <div className="py-4 text-center">
          <p className="text-xs text-gray-500">
            PiSignage Premium v2.0 • Conçu avec passion • 
            <span className="text-ruby ml-1">Performance optimale garantie</span>
          </p>
        </div>
      </footer>
    </div>
  );
}