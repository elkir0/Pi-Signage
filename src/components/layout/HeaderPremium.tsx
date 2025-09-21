'use client';

import React, { useState, useEffect } from 'react';
import { Activity, Wifi, HardDrive, Cpu, Zap, Clock, Volume2 } from 'lucide-react';
import Image from 'next/image';

export default function HeaderPremium() {
  const [systemStats, setSystemStats] = useState({
    cpu: 0,
    memory: 0,
    disk: 0,
    network: true,
    uptime: '00:00'
  });
  
  const [currentTime, setCurrentTime] = useState(new Date());
  
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
      // Simuler des stats dynamiques
      setSystemStats({
        cpu: Math.floor(Math.random() * 30 + 10),
        memory: Math.floor(Math.random() * 20 + 60),
        disk: 75,
        network: true,
        uptime: '14:32'
      });
    }, 1000);
    
    return () => clearInterval(timer);
  }, []);

  return (
    <header className="relative overflow-hidden">
      {/* Background animé */}
      <div className="absolute inset-0 bg-gradient-to-r from-midnight via-obsidian to-charcoal opacity-90" />
      <div className="absolute inset-0">
        <div className="absolute inset-0 bg-gradient-to-r from-crimson/10 via-transparent to-sapphire/10 animate-gradient" />
        <div className="absolute top-0 left-0 w-96 h-96 bg-ruby/10 rounded-full filter blur-3xl animate-pulse-glow" />
        <div className="absolute bottom-0 right-0 w-96 h-96 bg-sapphire/10 rounded-full filter blur-3xl animate-float" />
      </div>
      
      {/* Contenu */}
      <div className="relative z-10 px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo et Titre */}
          <div className="flex items-center space-x-4">
            <div className="relative group">
              <div className="absolute -inset-1 bg-gradient-to-r from-crimson to-ruby rounded-lg blur opacity-75 group-hover:opacity-100 transition duration-1000 group-hover:duration-200"></div>
              <div className="relative bg-black rounded-lg p-2">
                <Image 
                  src="/pisignage-logo.png" 
                  alt="PiSignage Logo" 
                  width={48}
                  height={48}
                  className="relative z-10 animate-float"
                  priority
                />
              </div>
            </div>
            
            <div className="space-y-1">
              <h1 className="text-3xl font-bold">
                <span className="text-gradient-premium animate-shimmer">PiSignage</span>
              </h1>
              <div className="flex items-center space-x-3 text-xs">
                <span className="px-2 py-1 bg-emerald/20 text-emerald rounded-full border border-emerald/30 flex items-center gap-1">
                  <span className="w-2 h-2 bg-emerald rounded-full animate-pulse"></span>
                  System Active
                </span>
                <span className="text-gray-400">v2.0.0 Premium</span>
              </div>
            </div>
          </div>
          
          {/* Stats en temps réel */}
          <div className="flex items-center space-x-6">
            {/* CPU */}
            <div className="glass-morphism px-4 py-2 rounded-xl">
              <div className="flex items-center space-x-2">
                <Cpu className="w-4 h-4 text-amber" />
                <div>
                  <p className="text-xs text-gray-400">CPU</p>
                  <p className="text-sm font-bold text-white">{systemStats.cpu}%</p>
                </div>
                <div className="w-12 h-1 bg-charcoal rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-emerald to-amber transition-all duration-300"
                    style={{ width: `${systemStats.cpu}%` }}
                  />
                </div>
              </div>
            </div>
            
            {/* Memory */}
            <div className="glass-morphism px-4 py-2 rounded-xl">
              <div className="flex items-center space-x-2">
                <HardDrive className="w-4 h-4 text-sapphire" />
                <div>
                  <p className="text-xs text-gray-400">RAM</p>
                  <p className="text-sm font-bold text-white">{systemStats.memory}%</p>
                </div>
                <div className="w-12 h-1 bg-charcoal rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-sapphire to-ruby transition-all duration-300"
                    style={{ width: `${systemStats.memory}%` }}
                  />
                </div>
              </div>
            </div>
            
            {/* Network */}
            <div className="glass-morphism px-4 py-2 rounded-xl">
              <div className="flex items-center space-x-2">
                <Wifi className={`w-4 h-4 ${systemStats.network ? 'text-emerald' : 'text-red-500'}`} />
                <div>
                  <p className="text-xs text-gray-400">Network</p>
                  <p className="text-sm font-bold text-white">
                    {systemStats.network ? 'Online' : 'Offline'}
                  </p>
                </div>
              </div>
            </div>
            
            {/* Uptime */}
            <div className="glass-morphism px-4 py-2 rounded-xl">
              <div className="flex items-center space-x-2">
                <Zap className="w-4 h-4 text-coral" />
                <div>
                  <p className="text-xs text-gray-400">Uptime</p>
                  <p className="text-sm font-bold text-white">{systemStats.uptime}</p>
                </div>
              </div>
            </div>
            
            {/* Horloge */}
            <div className="glass-morphism px-4 py-3 rounded-xl min-w-[140px]">
              <div className="flex items-center space-x-2">
                <Clock className="w-4 h-4 text-ruby animate-pulse" />
                <div>
                  <p className="text-lg font-mono font-bold text-white">
                    {currentTime.toLocaleTimeString('fr-FR')}
                  </p>
                  <p className="text-xs text-gray-400">
                    {currentTime.toLocaleDateString('fr-FR', { 
                      day: 'numeric', 
                      month: 'short',
                      year: 'numeric'
                    })}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Bordure animée */}
      <div className="absolute bottom-0 left-0 right-0 h-[2px]">
        <div className="h-full bg-gradient-to-r from-transparent via-ruby to-transparent animate-shimmer" />
      </div>
    </header>
  );
}