'use client';

import React, { useState, useEffect } from 'react';
import { Play, Pause, Square, Volume2, HardDrive, Cpu, Thermometer, Wifi, Monitor, RefreshCw } from 'lucide-react';
import Screenshot from './Screenshot';

interface SystemInfo {
  cpu: number;
  memory: { used: number; total: number; percentage: number };
  disk: { used: number; total: number; percentage: number };
  temperature: number;
  vlcStatus: 'playing' | 'paused' | 'stopped';
  currentMedia?: string;
  uptime: string;
  network: { ip: string; hostname: string };
}

export default function Dashboard() {
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [volume, setVolume] = useState(50);

  const fetchSystemInfo = async () => {
    try {
      const response = await fetch('/api/system');
      const data = await response.json();
      setSystemInfo(data);
    } catch (error) {
      console.error('Failed to fetch system info:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSystemInfo();
    const interval = setInterval(fetchSystemInfo, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleVLCControl = async (action: 'play' | 'pause' | 'stop') => {
    try {
      await fetch('/api/system/vlc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action })
      });
      setTimeout(fetchSystemInfo, 1000);
    } catch (error) {
      console.error('VLC control failed:', error);
    }
  };

  const handleVolumeChange = async (newVolume: number) => {
    setVolume(newVolume);
    try {
      await fetch('/api/system/volume', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ volume: newVolume })
      });
    } catch (error) {
      console.error('Volume control failed:', error);
    }
  };

  const formatBytes = (bytes: number) => {
    const gb = bytes / (1024 * 1024 * 1024);
    return `${gb.toFixed(1)} GB`;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="ps-card-accent flex items-center space-x-3 px-6 py-4">
          <div className="ps-animate-pulse w-6 h-6 bg-red-600 rounded-full" />
          <span className="ps-gradient-text text-lg font-medium">Chargement du tableau de bord...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Hero Header */}
      <div className="text-center mb-12 ps-animate-fade-in">
        <h1 className="text-5xl lg:text-6xl font-bold ps-gradient-text mb-4 ps-animate-shimmer">
          Control Center
        </h1>
        <p className="text-xl text-white/70 font-light tracking-wide">
          Système de signalisation numérique haute performance
        </p>
        <div className="mt-6 flex justify-center">
          <div className="ps-glass px-6 py-2 rounded-full border border-red-600/30">
            <span className="text-emerald-400 font-medium">🟢 Système opérationnel</span>
          </div>
        </div>
      </div>

      {/* VLC Control Panel */}
      <div className="ps-card-enhanced p-8 ps-animate-slide-up">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold ps-gradient-text flex items-center gap-3">
            <div className="p-2 ps-surface rounded-lg">
              <Monitor className="w-6 h-6 text-red-500" />
            </div>
            Contrôle Multimédia VLC
          </h2>
          <div className={`px-4 py-2 rounded-full text-sm font-medium ${
            systemInfo?.vlcStatus === 'playing' ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' :
            systemInfo?.vlcStatus === 'paused' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' :
            'bg-red-500/20 text-red-400 border border-red-500/30'
          }`}>
            {systemInfo?.vlcStatus === 'playing' ? '🟢 Lecture' :
             systemInfo?.vlcStatus === 'paused' ? '🟡 Pause' : '🔴 Arrêté'}
          </div>
        </div>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-6">
            {/* Control Buttons */}
            <div className="flex flex-wrap gap-3">
              <button
                onClick={() => handleVLCControl('play')}
                className="ps-btn-primary flex items-center gap-2 transition-smooth"
              >
                <Play className="w-5 h-5" /> 
                <span>Lecture</span>
              </button>
              <button
                onClick={() => handleVLCControl('pause')}
                className="ps-btn-secondary flex items-center gap-2"
              >
                <Pause className="w-5 h-5" /> 
                <span>Pause</span>
              </button>
              <button
                onClick={() => handleVLCControl('stop')}
                className="ps-btn-ghost flex items-center gap-2"
              >
                <Square className="w-5 h-5" /> 
                <span>Arrêt</span>
              </button>
            </div>
            
            {/* Volume Control */}
            <div className="ps-surface p-4 rounded-xl">
              <label className="flex items-center gap-3 text-white/80 mb-3">
                <Volume2 className="w-5 h-5 text-red-500" /> 
                <span className="font-medium">Volume: </span>
                <span className="ps-gradient-text font-bold">{volume}%</span>
              </label>
              <div className="relative">
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={volume}
                  onChange={(e) => handleVolumeChange(Number(e.target.value))}
                  className="w-full h-3 bg-ps-obsidian rounded-full appearance-none cursor-pointer slider"
                />
                <style jsx>{`
                  .slider::-webkit-slider-thumb {
                    appearance: none;
                    width: 20px;
                    height: 20px;
                    border-radius: 50%;
                    background: linear-gradient(135deg, #DC2626, #EF4444);
                    cursor: pointer;
                    box-shadow: 0 0 10px rgba(220, 38, 38, 0.5);
                  }
                `}</style>
              </div>
            </div>
            
            {/* Current Media */}
            {systemInfo?.currentMedia && (
              <div className="ps-surface p-4 rounded-xl">
                <span className="text-white/60 text-sm font-medium">Média en cours:</span>
                <p className="text-white font-mono text-sm mt-1 truncate bg-ps-obsidian/50 px-3 py-2 rounded-lg">
                  {systemInfo.currentMedia}
                </p>
              </div>
            )}
          </div>
          
          {/* Status Visualization */}
          <div className="flex flex-col items-center justify-center space-y-4">
            <div className={`text-8xl transition-all duration-500 transform ${
              systemInfo?.vlcStatus === 'playing' ? 'text-emerald-400 ps-animate-glow scale-110' :
              systemInfo?.vlcStatus === 'paused' ? 'text-amber-400 scale-105' :
              'text-red-400 scale-100'
            }`}>
              {systemInfo?.vlcStatus === 'playing' ? '▶' :
               systemInfo?.vlcStatus === 'paused' ? '⏸' : '⏹'}
            </div>
            <div className="text-center">
              <p className="text-white/60 text-sm">État du lecteur</p>
              <p className="text-white font-semibold capitalize">
                {systemInfo?.vlcStatus === 'playing' ? 'En lecture' :
                 systemInfo?.vlcStatus === 'paused' ? 'En pause' : 'Arrêté'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* System Performance Stats */}
      <div className="space-y-6">
        <h2 className="text-2xl font-bold ps-gradient-text flex items-center gap-3">
          <div className="p-2 ps-surface rounded-lg">
            <Cpu className="w-6 h-6 text-red-500" />
          </div>
          Performances Système
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
          {/* CPU Card */}
          <div className="ps-card-accent ps-animate-slide-up group hover:scale-105 transition-transform">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="p-3 ps-surface rounded-xl group-hover:shadow-red-600/50 transition-all">
                  <Cpu className="w-6 h-6 text-red-500" />
                </div>
                <div>
                  <p className="text-white/60 text-sm font-medium">Processeur</p>
                  <p className="text-white/40 text-xs">Utilisation</p>
                </div>
              </div>
            </div>
            <div className="text-3xl font-bold ps-gradient-text mb-3">
              {systemInfo?.cpu.toFixed(1)}%
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-xs text-white/60">
                <span>Charge</span>
                <span>{systemInfo?.cpu.toFixed(0)}%</span>
              </div>
              <div className="h-2 ps-surface rounded-full overflow-hidden">
                <div 
                  className="h-full bg-gradient-to-r from-red-600 to-red-500 transition-all duration-1000 ease-out"
                  style={{ width: `${systemInfo?.cpu}%` }}
                />
              </div>
            </div>
          </div>

          {/* Memory Card */}
          <div className="ps-card-accent ps-animate-slide-up group hover:scale-105 transition-transform animation-delay-200">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="p-3 ps-surface rounded-xl group-hover:shadow-red-600/50 transition-all">
                  <HardDrive className="w-6 h-6 text-amber-400" />
                </div>
                <div>
                  <p className="text-white/60 text-sm font-medium">Mémoire</p>
                  <p className="text-white/40 text-xs">RAM Système</p>
                </div>
              </div>
            </div>
            <div className="text-3xl font-bold ps-gradient-text mb-3">
              {systemInfo?.memory.percentage.toFixed(1)}%
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-xs text-white/60">
                <span>{formatBytes(systemInfo?.memory.used || 0)}</span>
                <span>{formatBytes(systemInfo?.memory.total || 0)}</span>
              </div>
              <div className="h-2 ps-surface rounded-full overflow-hidden">
                <div 
                  className="h-full bg-gradient-to-r from-amber-500 to-orange-500 transition-all duration-1000 ease-out"
                  style={{ width: `${systemInfo?.memory.percentage}%` }}
                />
              </div>
            </div>
          </div>

          {/* Disk Card */}
          <div className="ps-card-accent ps-animate-slide-up group hover:scale-105 transition-transform animation-delay-400">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="p-3 ps-surface rounded-xl group-hover:shadow-red-600/50 transition-all">
                  <HardDrive className="w-6 h-6 text-blue-400" />
                </div>
                <div>
                  <p className="text-white/60 text-sm font-medium">Stockage</p>
                  <p className="text-white/40 text-xs">Disque Dur</p>
                </div>
              </div>
            </div>
            <div className="text-3xl font-bold ps-gradient-text mb-3">
              {systemInfo?.disk.percentage.toFixed(1)}%
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-xs text-white/60">
                <span>{formatBytes(systemInfo?.disk.used || 0)}</span>
                <span>{formatBytes(systemInfo?.disk.total || 0)}</span>
              </div>
              <div className="h-2 ps-surface rounded-full overflow-hidden">
                <div 
                  className="h-full bg-gradient-to-r from-blue-500 to-cyan-500 transition-all duration-1000 ease-out"
                  style={{ width: `${systemInfo?.disk.percentage}%` }}
                />
              </div>
            </div>
          </div>

          {/* Temperature Card */}
          <div className="ps-card-accent ps-animate-slide-up group hover:scale-105 transition-transform animation-delay-600">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="p-3 ps-surface rounded-xl group-hover:shadow-red-600/50 transition-all">
                  <Thermometer className={`w-6 h-6 ${
                    (systemInfo?.temperature || 0) > 70 ? 'text-red-400' : 
                    (systemInfo?.temperature || 0) > 50 ? 'text-orange-400' : 
                    'text-emerald-400'
                  }`} />
                </div>
                <div>
                  <p className="text-white/60 text-sm font-medium">Température</p>
                  <p className="text-white/40 text-xs">CPU Core</p>
                </div>
              </div>
            </div>
            <div className="text-3xl font-bold ps-gradient-text mb-3">
              {systemInfo?.temperature.toFixed(1)}°C
            </div>
            <div className="space-y-2">
              <div className={`text-sm font-medium ${
                (systemInfo?.temperature || 0) > 70 ? 'text-red-400' : 
                (systemInfo?.temperature || 0) > 50 ? 'text-orange-400' : 
                'text-emerald-400'
              }`}>
                {(systemInfo?.temperature || 0) > 70 ? '🔥 Attention - Chaud' : 
                 (systemInfo?.temperature || 0) > 50 ? '⚠️ Normal - Tiède' : 
                 '❄️ Optimal - Froid'}
              </div>
              <div className="h-2 ps-surface rounded-full overflow-hidden">
                <div 
                  className={`h-full transition-all duration-1000 ease-out ${
                    (systemInfo?.temperature || 0) > 70 ? 'bg-gradient-to-r from-red-500 to-red-600' : 
                    (systemInfo?.temperature || 0) > 50 ? 'bg-gradient-to-r from-orange-500 to-orange-600' : 
                    'bg-gradient-to-r from-emerald-500 to-emerald-600'
                  }`}
                  style={{ width: `${Math.min((systemInfo?.temperature || 0) / 80 * 100, 100)}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Network Information */}
      <div className="ps-card-enhanced p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 ps-surface rounded-lg">
            <Wifi className="w-6 h-6 text-emerald-400" />
          </div>
          <h3 className="text-2xl font-bold ps-gradient-text">Informations Réseau</h3>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="ps-surface p-4 rounded-xl space-y-2">
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse" />
              <span className="text-white/60 text-sm font-medium">Adresse IP</span>
            </div>
            <p className="text-white font-mono text-lg bg-ps-obsidian/50 px-3 py-2 rounded-lg">
              {systemInfo?.network.ip || 'N/A'}
            </p>
          </div>
          
          <div className="ps-surface p-4 rounded-xl space-y-2">
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 bg-blue-500 rounded-full animate-pulse" />
              <span className="text-white/60 text-sm font-medium">Nom d'hôte</span>
            </div>
            <p className="text-white font-mono text-lg bg-ps-obsidian/50 px-3 py-2 rounded-lg">
              {systemInfo?.network.hostname || 'N/A'}
            </p>
          </div>
          
          <div className="ps-surface p-4 rounded-xl space-y-2">
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 bg-amber-500 rounded-full animate-pulse" />
              <span className="text-white/60 text-sm font-medium">Temps de fonctionnement</span>
            </div>
            <p className="text-white text-lg bg-ps-obsidian/50 px-3 py-2 rounded-lg">
              {systemInfo?.uptime || 'N/A'}
            </p>
          </div>
        </div>
      </div>

      {/* Screenshot Section */}
      <div className="ps-card-enhanced p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 ps-surface rounded-lg">
              <Monitor className="w-6 h-6 text-purple-400" />
            </div>
            <h3 className="text-2xl font-bold ps-gradient-text">Capture d'Écran en Temps Réel</h3>
          </div>
          <div className="px-3 py-1 bg-purple-500/20 text-purple-400 border border-purple-500/30 rounded-full text-sm">
            Live Preview
          </div>
        </div>
        <div className="ps-surface p-4 rounded-xl">
          <Screenshot />
        </div>
      </div>

      {/* Refresh Controls */}
      <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
        <button
          onClick={fetchSystemInfo}
          className="ps-btn-primary flex items-center gap-3 px-8 py-3"
        >
          <RefreshCw className="w-5 h-5" />
          <span className="font-medium">Actualiser les Données</span>
        </button>
        
        <div className="flex items-center gap-2 text-white/60 text-sm">
          <span className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse" />
          <span>Mise à jour automatique toutes les 5 secondes</span>
        </div>
      </div>
    </div>
  );
}