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
        <div className="animate-pulse text-red-600">Chargement...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold text-gradient-free mb-2">
          PiSignage Control Center
        </h1>
        <p className="text-gray-400">Système de signalisation numérique</p>
      </div>

      {/* VLC Control Panel */}
      <div className="card-free glow-red p-6">
        <h2 className="text-xl font-bold text-red-500 mb-4 flex items-center gap-2">
          <Monitor className="w-6 h-6" />
          Contrôle VLC
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <div className="flex gap-2 mb-4">
              <button
                onClick={() => handleVLCControl('play')}
                className="btn-free flex items-center gap-2"
              >
                <Play className="w-4 h-4" /> Play
              </button>
              <button
                onClick={() => handleVLCControl('pause')}
                className="btn-free flex items-center gap-2"
              >
                <Pause className="w-4 h-4" /> Pause
              </button>
              <button
                onClick={() => handleVLCControl('stop')}
                className="btn-free flex items-center gap-2"
              >
                <Square className="w-4 h-4" /> Stop
              </button>
            </div>
            
            <div className="mb-4">
              <label className="flex items-center gap-2 text-sm text-gray-400 mb-2">
                <Volume2 className="w-4 h-4" /> Volume: {volume}%
              </label>
              <input
                type="range"
                min="0"
                max="100"
                value={volume}
                onChange={(e) => handleVolumeChange(Number(e.target.value))}
                className="w-full accent-red-600"
              />
            </div>
            
            {systemInfo?.currentMedia && (
              <div className="text-sm">
                <span className="text-gray-400">Média actuel:</span>
                <p className="text-white truncate">{systemInfo.currentMedia}</p>
              </div>
            )}
          </div>
          
          <div className="flex items-center justify-center">
            <div className={`text-6xl ${
              systemInfo?.vlcStatus === 'playing' ? 'text-green-500 animate-pulse' :
              systemInfo?.vlcStatus === 'paused' ? 'text-yellow-500' :
              'text-red-500'
            }`}>
              {systemInfo?.vlcStatus === 'playing' ? '▶' :
               systemInfo?.vlcStatus === 'paused' ? '⏸' : '⏹'}
            </div>
          </div>
        </div>
      </div>

      {/* System Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">CPU</span>
            <Cpu className="w-4 h-4 text-red-500" />
          </div>
          <div className="text-2xl font-bold text-white">
            {systemInfo?.cpu.toFixed(1)}%
          </div>
          <div className="mt-2 h-2 bg-gray-800 rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-red-600 to-red-400 transition-all"
              style={{ width: `${systemInfo?.cpu}%` }}
            />
          </div>
        </div>

        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Mémoire</span>
            <HardDrive className="w-4 h-4 text-red-500" />
          </div>
          <div className="text-2xl font-bold text-white">
            {systemInfo?.memory.percentage.toFixed(1)}%
          </div>
          <div className="text-xs text-gray-400">
            {formatBytes(systemInfo?.memory.used || 0)} / {formatBytes(systemInfo?.memory.total || 0)}
          </div>
        </div>

        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Disque</span>
            <HardDrive className="w-4 h-4 text-red-500" />
          </div>
          <div className="text-2xl font-bold text-white">
            {systemInfo?.disk.percentage.toFixed(1)}%
          </div>
          <div className="text-xs text-gray-400">
            {formatBytes(systemInfo?.disk.used || 0)} / {formatBytes(systemInfo?.disk.total || 0)}
          </div>
        </div>

        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Température</span>
            <Thermometer className="w-4 h-4 text-red-500" />
          </div>
          <div className="text-2xl font-bold text-white">
            {systemInfo?.temperature.toFixed(1)}°C
          </div>
          <div className={`text-xs ${
            (systemInfo?.temperature || 0) > 70 ? 'text-red-400' : 
            (systemInfo?.temperature || 0) > 50 ? 'text-yellow-400' : 
            'text-green-400'
          }`}>
            {(systemInfo?.temperature || 0) > 70 ? 'Chaud' : 
             (systemInfo?.temperature || 0) > 50 ? 'Normal' : 'Froid'}
          </div>
        </div>
      </div>

      {/* Network Info */}
      <div className="card-free p-4">
        <div className="flex items-center gap-2 mb-3">
          <Wifi className="w-5 h-5 text-red-500" />
          <h3 className="text-lg font-semibold text-white">Réseau</h3>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <span className="text-gray-400">Adresse IP:</span>
            <p className="text-white font-mono">{systemInfo?.network.ip || 'N/A'}</p>
          </div>
          <div>
            <span className="text-gray-400">Hostname:</span>
            <p className="text-white font-mono">{systemInfo?.network.hostname || 'N/A'}</p>
          </div>
          <div>
            <span className="text-gray-400">Uptime:</span>
            <p className="text-white">{systemInfo?.uptime || 'N/A'}</p>
          </div>
        </div>
      </div>

      {/* Screenshot Section */}
      <div className="card-free p-6">
        <h3 className="text-xl font-bold text-red-500 mb-4">Capture d'écran</h3>
        <Screenshot />
      </div>

      {/* Refresh Button */}
      <div className="flex justify-center">
        <button
          onClick={fetchSystemInfo}
          className="btn-free flex items-center gap-2"
        >
          <RefreshCw className="w-4 h-4" />
          Actualiser les informations
        </button>
      </div>
    </div>
  );
}