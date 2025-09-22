'use client';

import React, { useState, useEffect } from 'react';
import { 
  Play, Pause, SkipForward, Volume2, 
  Eye, Clock, Server, TrendingUp,
  Activity, HardDrive, Cpu, Wifi
} from 'lucide-react';

export default function DashboardPremium() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [metrics, setMetrics] = useState({
    views: 1247,
    activeDisplays: 3,
    uptime: '14h 32m',
    cpuUsage: 25,
    memoryUsage: 62,
    diskUsage: 45
  });

  useEffect(() => {
    const interval = setInterval(() => {
      setMetrics(prev => ({
        ...prev,
        views: prev.views + Math.floor(Math.random() * 5),
        cpuUsage: Math.floor(Math.random() * 30 + 10),
        memoryUsage: Math.floor(Math.random() * 20 + 50)
      }));
    }, 5000);
    
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-6 space-y-6 animate-slide-up">
      {/* Métriques principales */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Vues totales */}
        <div className="ps-card">
          <div className="flex items-center justify-between mb-4">
            <Eye className="w-5 h-5 ps-text-accent" />
            <span className="text-xs text-green-400">+12%</span>
          </div>
          <p className="ps-text-muted text-sm mb-1">Vues totales</p>
          <p className="text-2xl font-bold ps-text-primary">
            {metrics.views.toLocaleString()}
          </p>
        </div>

        {/* Écrans actifs */}
        <div className="ps-card">
          <div className="flex items-center justify-between mb-4">
            <Server className="w-5 h-5 ps-text-accent" />
            <span className="ps-badge-success">Online</span>
          </div>
          <p className="ps-text-muted text-sm mb-1">Écrans actifs</p>
          <p className="text-2xl font-bold ps-text-primary">
            {metrics.activeDisplays}/4
          </p>
        </div>

        {/* Temps actif */}
        <div className="ps-card">
          <div className="flex items-center justify-between mb-4">
            <Clock className="w-5 h-5 ps-text-accent" />
            <Activity className="w-4 h-4 text-green-400" />
          </div>
          <p className="ps-text-muted text-sm mb-1">Temps actif</p>
          <p className="text-2xl font-bold ps-text-primary">
            {metrics.uptime}
          </p>
        </div>

        {/* CPU Usage */}
        <div className="ps-card">
          <div className="flex items-center justify-between mb-4">
            <Cpu className="w-5 h-5 ps-text-accent" />
            <span className="text-xs ps-text-muted">{metrics.cpuUsage}%</span>
          </div>
          <p className="ps-text-muted text-sm mb-1">Utilisation CPU</p>
          <div className="w-full h-2 bg-gray-700 rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-red-600 to-red-400 transition-all"
              style={{ width: `${metrics.cpuUsage}%` }}
            />
          </div>
        </div>
      </div>

      {/* Lecteur vidéo et contrôles */}
      <div className="ps-card">
        <h3 className="text-lg font-semibold ps-text-primary mb-4">
          Lecture en cours
        </h3>
        
        {/* Aperçu vidéo */}
        <div className="aspect-video bg-gray-900 rounded-lg mb-4 flex items-center justify-center">
          <div className="text-center">
            <div className="ps-glow-crimson rounded-full p-4 inline-block mb-2">
              {isPlaying ? (
                <Pause className="w-8 h-8 ps-text-accent" />
              ) : (
                <Play className="w-8 h-8 ps-text-accent" />
              )}
            </div>
            <p className="ps-text-muted text-sm">
              {isPlaying ? 'Diffusion en cours...' : 'Aucune diffusion active'}
            </p>
          </div>
        </div>

        {/* Contrôles de lecture */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <button 
              onClick={() => setIsPlaying(!isPlaying)}
              className="ps-btn-primary"
            >
              {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
            </button>
            <button className="ps-btn-secondary">
              <SkipForward className="w-4 h-4" />
            </button>
          </div>
          
          <div className="flex items-center gap-2">
            <Volume2 className="w-4 h-4 ps-text-muted" />
            <input 
              type="range" 
              min="0" 
              max="100" 
              className="w-24"
              style={{ accentColor: '#DC2626' }}
            />
          </div>
        </div>
      </div>

      {/* Statut système */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Mémoire */}
        <div className="ps-card">
          <div className="flex items-center gap-2 mb-3">
            <HardDrive className="w-4 h-4 ps-text-accent" />
            <span className="ps-text-primary font-medium">Mémoire</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="ps-text-muted">Utilisé</span>
              <span className="ps-text-primary">{metrics.memoryUsage}%</span>
            </div>
            <div className="w-full h-2 bg-gray-700 rounded-full overflow-hidden">
              <div 
                className="h-full bg-gradient-to-r from-blue-600 to-blue-400"
                style={{ width: `${metrics.memoryUsage}%` }}
              />
            </div>
          </div>
        </div>

        {/* Disque */}
        <div className="ps-card">
          <div className="flex items-center gap-2 mb-3">
            <HardDrive className="w-4 h-4 ps-text-accent" />
            <span className="ps-text-primary font-medium">Stockage</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="ps-text-muted">Utilisé</span>
              <span className="ps-text-primary">{metrics.diskUsage}%</span>
            </div>
            <div className="w-full h-2 bg-gray-700 rounded-full overflow-hidden">
              <div 
                className="h-full bg-gradient-to-r from-green-600 to-green-400"
                style={{ width: `${metrics.diskUsage}%` }}
              />
            </div>
          </div>
        </div>

        {/* Réseau */}
        <div className="ps-card">
          <div className="flex items-center gap-2 mb-3">
            <Wifi className="w-4 h-4 ps-text-accent" />
            <span className="ps-text-primary font-medium">Réseau</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="ps-status-online text-sm">Connecté</span>
            <span className="ps-text-muted text-xs">192.168.1.103</span>
          </div>
        </div>
      </div>
    </div>
  );
}