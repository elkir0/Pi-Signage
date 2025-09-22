'use client';

import React, { useState, useEffect } from 'react';
import { Activity, Wifi, Cpu, Clock } from 'lucide-react';
import Image from 'next/image';

export default function HeaderPremium() {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [systemStatus, setSystemStatus] = useState({
    cpu: 12,
    network: true,
  });
  
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
      // Update system status every 5 seconds
      if (Math.random() > 0.8) {
        setSystemStatus({
          cpu: Math.floor(Math.random() * 30 + 10),
          network: true,
        });
      }
    }, 1000);
    
    return () => clearInterval(timer);
  }, []);

  return (
    <header className="ps-bg-primary border-b border-red-600/30">
      <div className="px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo et Titre (simplifié) */}
          <div className="flex items-center space-x-4">
            <div className="relative">
              <div className="ps-glow-crimson rounded-xl">
                <Image 
                  src="/pisignage-logo.png" 
                  alt="PiSignage Logo" 
                  width={48}
                  height={48}
                  className="rounded-xl"
                  priority
                />
              </div>
            </div>
            
            <div>
              <h1 className="text-2xl font-bold ps-text-primary">
                PiSignage
              </h1>
              <div className="flex items-center gap-2">
                <span className="ps-status-online text-sm text-green-400">
                  Système actif
                </span>
                <span className="text-xs ps-text-muted">v2.0</span>
              </div>
            </div>
          </div>
          
          {/* Stats minimales (seulement les essentielles) */}
          <div className="flex items-center space-x-4">
            {/* CPU */}
            <div className="ps-surface px-3 py-2 flex items-center gap-2">
              <Cpu className="w-4 h-4 ps-text-accent" />
              <span className="text-sm ps-text-primary">{systemStatus.cpu}%</span>
            </div>
            
            {/* Network */}
            <div className="ps-surface px-3 py-2 flex items-center gap-2">
              <Wifi className={`w-4 h-4 ${systemStatus.network ? 'text-green-400' : 'text-gray-500'}`} />
              <span className="text-sm ps-text-primary">
                {systemStatus.network ? 'Online' : 'Offline'}
              </span>
            </div>
            
            {/* Horloge */}
            <div className="ps-card-elevated px-4 py-2">
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 ps-text-accent" />
                <div>
                  <p className="text-sm font-semibold ps-text-primary">
                    {currentTime.toLocaleTimeString('fr-FR', {
                      hour: '2-digit',
                      minute: '2-digit'
                    })}
                  </p>
                  <p className="text-xs ps-text-muted">
                    {currentTime.toLocaleDateString('fr-FR', { 
                      day: 'numeric', 
                      month: 'short'
                    })}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Simple accent line */}
      <div className="h-[1px] bg-gradient-to-r from-transparent via-red-600/50 to-transparent" />
    </header>
  );
}