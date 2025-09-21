'use client';

import React, { useState, useEffect } from 'react';
import { 
  Play, Pause, SkipForward, Volume2, Maximize, 
  TrendingUp, Users, Eye, Clock, Zap,
  BarChart3, PieChart, Activity, Wifi,
  HardDrive, Cpu, ThermometerSun, Server
} from 'lucide-react';

export default function DashboardPremium() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [volume, setVolume] = useState(50);
  const [metrics, setMetrics] = useState({
    views: 1247,
    activeDisplays: 3,
    uptime: '14h 32m',
    efficiency: 94
  });

  useEffect(() => {
    // Simuler des métriques dynamiques
    const interval = setInterval(() => {
      setMetrics(prev => ({
        views: prev.views + Math.floor(Math.random() * 5),
        activeDisplays: 3,
        uptime: '14h 32m',
        efficiency: Math.min(100, prev.efficiency + (Math.random() - 0.5))
      }));
    }, 3000);
    
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6 p-6 animate-slide-up">
      {/* Section Hero avec métriques principales */}
      <div className="grid grid-cols-4 gap-4">
        {/* Carte Vues */}
        <div className="glass-card p-6 relative group card-3d">
          <div className="absolute top-2 right-2">
            <div className="w-2 h-2 bg-emerald rounded-full animate-pulse" />
          </div>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-400 text-sm mb-1">Vues totales</p>
              <p className="text-3xl font-bold text-white">
                {metrics.views.toLocaleString()}
              </p>
              <div className="flex items-center mt-2 text-emerald text-sm">
                <TrendingUp className="w-4 h-4 mr-1" />
                <span>+12% aujourd'hui</span>
              </div>
            </div>
            <div className="p-4 bg-gradient-to-br from-emerald/20 to-teal-500/20 rounded-xl">
              <Eye className="w-8 h-8 text-emerald" />
            </div>
          </div>
          <div className="mt-4 h-2 bg-charcoal rounded-full overflow-hidden">
            <div className="h-full bg-gradient-to-r from-emerald to-teal-500 animate-shimmer" style={{ width: '67%' }} />
          </div>
        </div>

        {/* Carte Displays Actifs */}
        <div className="glass-card p-6 relative group card-3d">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-400 text-sm mb-1">Écrans actifs</p>
              <p className="text-3xl font-bold text-white">{metrics.activeDisplays}/4</p>
              <div className="flex items-center mt-2 text-sapphire text-sm">
                <Server className="w-4 h-4 mr-1" />
                <span>Tous connectés</span>
              </div>
            </div>
            <div className="p-4 bg-gradient-to-br from-sapphire/20 to-indigo-600/20 rounded-xl">
              <Users className="w-8 h-8 text-sapphire" />
            </div>
          </div>
          <div className="mt-4 flex space-x-1">
            {[1, 2, 3, 4].map((i) => (
              <div
                key={i}
                className={`flex-1 h-2 rounded-full ${
                  i <= metrics.activeDisplays 
                    ? 'bg-gradient-to-r from-sapphire to-indigo-600' 
                    : 'bg-charcoal'
                }`}
              />
            ))}
          </div>
        </div>

        {/* Carte Uptime */}
        <div className="glass-card p-6 relative group card-3d">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-400 text-sm mb-1">Temps actif</p>
              <p className="text-3xl font-bold text-white">{metrics.uptime}</p>
              <div className="flex items-center mt-2 text-amber text-sm">
                <Clock className="w-4 h-4 mr-1" />
                <span>99.9% disponibilité</span>
              </div>
            </div>
            <div className="p-4 bg-gradient-to-br from-amber/20 to-orange-600/20 rounded-xl">
              <Zap className="w-8 h-8 text-amber animate-pulse" />
            </div>
          </div>
          <div className="mt-4 h-2 bg-charcoal rounded-full overflow-hidden">
            <div className="h-full bg-gradient-to-r from-amber to-orange-600" style={{ width: '99.9%' }} />
          </div>
        </div>

        {/* Carte Efficacité */}
        <div className="glass-card p-6 relative group card-3d">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-400 text-sm mb-1">Efficacité</p>
              <p className="text-3xl font-bold text-white">{Math.round(metrics.efficiency)}%</p>
              <div className="flex items-center mt-2 text-ruby text-sm">
                <BarChart3 className="w-4 h-4 mr-1" />
                <span>Optimal</span>
              </div>
            </div>
            <div className="p-4 bg-gradient-to-br from-ruby/20 to-crimson/20 rounded-xl">
              <Activity className="w-8 h-8 text-ruby" />
            </div>
          </div>
          <div className="mt-4 h-2 bg-charcoal rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-ruby to-crimson transition-all duration-500" 
              style={{ width: `${metrics.efficiency}%` }} 
            />
          </div>
        </div>
      </div>

      {/* Contrôle Media Player Premium */}
      <div className="glass-card p-6">
        <h3 className="text-xl font-bold mb-4 text-gradient-premium">Contrôle Média</h3>
        
        <div className="space-y-4">
          {/* Visualisation */}
          <div className="relative h-48 bg-charcoal rounded-xl overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-br from-ruby/10 to-sapphire/10" />
            
            {/* Barres de visualisation audio */}
            <div className="absolute bottom-0 left-0 right-0 flex items-end justify-center space-x-1 p-4">
              {[...Array(20)].map((_, i) => (
                <div
                  key={i}
                  className="w-2 bg-gradient-to-t from-ruby to-amber rounded-t animate-pulse"
                  style={{
                    height: `${Math.random() * 100}px`,
                    animationDelay: `${i * 50}ms`,
                    animationDuration: `${0.5 + Math.random()}s`
                  }}
                />
              ))}
            </div>
            
            {/* Info média */}
            <div className="absolute top-4 left-4">
              <p className="text-white font-bold">Playlist Active</p>
              <p className="text-gray-400 text-sm">Contenu promotionnel - Boucle 3/10</p>
            </div>
            
            {/* Timer */}
            <div className="absolute top-4 right-4 text-white font-mono">
              <span className="text-2xl">02:47</span>
              <span className="text-gray-400"> / 05:32</span>
            </div>
          </div>
          
          {/* Contrôles */}
          <div className="flex items-center justify-center space-x-4">
            <button className="p-3 rounded-full bg-white/5 hover:bg-white/10 transition-all hover:scale-110">
              <SkipForward className="w-5 h-5 text-white rotate-180" />
            </button>
            
            <button
              onClick={() => setIsPlaying(!isPlaying)}
              className="btn-premium rounded-full p-4 animate-pulse-glow"
            >
              {isPlaying ? (
                <Pause className="w-6 h-6 text-white" />
              ) : (
                <Play className="w-6 h-6 text-white translate-x-0.5" />
              )}
            </button>
            
            <button className="p-3 rounded-full bg-white/5 hover:bg-white/10 transition-all hover:scale-110">
              <SkipForward className="w-5 h-5 text-white" />
            </button>
          </div>
          
          {/* Volume et Fullscreen */}
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2 flex-1">
              <Volume2 className="w-5 h-5 text-gray-400" />
              <div className="flex-1 relative">
                <input
                  type="range"
                  value={volume}
                  onChange={(e) => setVolume(Number(e.target.value))}
                  className="w-full h-2 bg-charcoal rounded-full appearance-none cursor-pointer"
                  style={{
                    background: `linear-gradient(to right, #DC2626 0%, #DC2626 ${volume}%, #2A2A38 ${volume}%, #2A2A38 100%)`
                  }}
                />
              </div>
              <span className="text-sm text-gray-400 w-10">{volume}%</span>
            </div>
            
            <button className="p-2 rounded-lg bg-white/5 hover:bg-white/10 transition-all">
              <Maximize className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>
      </div>

      {/* Monitoring Système en temps réel */}
      <div className="grid grid-cols-2 gap-4">
        {/* Performance */}
        <div className="glass-card p-6">
          <h3 className="text-lg font-bold mb-4 text-white flex items-center gap-2">
            <Activity className="w-5 h-5 text-ruby" />
            Performance Système
          </h3>
          
          <div className="space-y-4">
            {/* CPU */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Cpu className="w-4 h-4 text-amber" />
                <span className="text-sm text-gray-400">Processeur</span>
              </div>
              <span className="text-white font-bold">24%</span>
            </div>
            <div className="h-2 bg-charcoal rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-amber to-orange-600" style={{ width: '24%' }} />
            </div>
            
            {/* RAM */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <HardDrive className="w-4 h-4 text-sapphire" />
                <span className="text-sm text-gray-400">Mémoire</span>
              </div>
              <span className="text-white font-bold">1.2 GB / 4 GB</span>
            </div>
            <div className="h-2 bg-charcoal rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-sapphire to-indigo-600" style={{ width: '30%' }} />
            </div>
            
            {/* Temperature */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ThermometerSun className="w-4 h-4 text-emerald" />
                <span className="text-sm text-gray-400">Température</span>
              </div>
              <span className="text-white font-bold">42°C</span>
            </div>
            <div className="h-2 bg-charcoal rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-emerald to-teal-500" style={{ width: '42%' }} />
            </div>
          </div>
        </div>
        
        {/* Network Status */}
        <div className="glass-card p-6">
          <h3 className="text-lg font-bold mb-4 text-white flex items-center gap-2">
            <Wifi className="w-5 h-5 text-emerald" />
            Statut Réseau
          </h3>
          
          <div className="space-y-3">
            <div className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
              <span className="text-gray-400 text-sm">Connexion</span>
              <span className="text-emerald font-bold flex items-center gap-1">
                <span className="w-2 h-2 bg-emerald rounded-full animate-pulse"></span>
                En ligne
              </span>
            </div>
            
            <div className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
              <span className="text-gray-400 text-sm">Adresse IP</span>
              <span className="text-white font-mono">192.168.1.103</span>
            </div>
            
            <div className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
              <span className="text-gray-400 text-sm">Débit</span>
              <span className="text-white">↓ 2.4 MB/s ↑ 0.8 MB/s</span>
            </div>
            
            <div className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
              <span className="text-gray-400 text-sm">Ping</span>
              <span className="text-emerald font-bold">12 ms</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}