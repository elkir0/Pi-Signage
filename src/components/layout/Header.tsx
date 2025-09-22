'use client';

import React from 'react';
import { Activity, Wifi, Cpu } from 'lucide-react';
import Image from 'next/image';

export default function Header() {
  return (
    <header className="ps-glass ps-border-glow relative overflow-hidden">
      {/* Background gradient overlay */}
      <div className="absolute inset-0 ps-gradient-primary opacity-30" />
      
      <div className="relative container mx-auto px-6 py-5">
        <div className="flex items-center justify-between">
          {/* Logo & Brand */}
          <div className="flex items-center space-x-4">
            <div className="relative w-14 h-14 ps-animate-float">
              <div className="absolute inset-0 ps-glow-crimson rounded-xl" />
              <Image 
                src="https://github.com/elkir0/Pi-Signage/blob/main/Pi%20signeage.png?raw=true" 
                alt="PiSignage Logo" 
                width={56}
                height={56}
                className="object-contain relative z-10 rounded-xl"
                priority
              />
            </div>
            <div className="space-y-1">
              <h1 className="text-3xl font-bold ps-gradient-text ps-animate-shimmer">
                PiSignage
              </h1>
              <div className="flex items-center space-x-2">
                <span className="text-xs font-medium text-white/70 tracking-wider uppercase">
                  Digital Signage System
                </span>
                <span className="px-2 py-0.5 bg-gradient-to-r from-emerald-500 to-emerald-600 text-xs font-bold text-white rounded-full">
                  v2.0
                </span>
              </div>
            </div>
          </div>
          
          {/* Status & Info */}
          <div className="flex items-center space-x-6">
            {/* System Status */}
            <div className="hidden md:flex items-center space-x-4">
              <div className="flex items-center space-x-2 ps-surface px-3 py-2 rounded-lg">
                <Activity className="w-4 h-4 text-emerald-400 ps-animate-glow" />
                <span className="text-sm font-medium text-emerald-400">Online</span>
              </div>
              
              <div className="flex items-center space-x-2 ps-surface px-3 py-2 rounded-lg">
                <Wifi className="w-4 h-4 text-blue-400" />
                <span className="text-sm text-blue-400">Connected</span>
              </div>
              
              <div className="flex items-center space-x-2 ps-surface px-3 py-2 rounded-lg">
                <Cpu className="w-4 h-4 text-amber-400" />
                <span className="text-sm text-amber-400">45°C</span>
              </div>
            </div>
            
            {/* Date & Time */}
            <div className="ps-card-elevated px-4 py-2">
              <div className="text-right">
                <div className="text-sm font-semibold text-white">
                  {new Date().toLocaleDateString('fr-FR', { 
                    day: 'numeric', 
                    month: 'short',
                    year: 'numeric' 
                  })}
                </div>
                <div className="text-xs text-white/60">
                  {new Date().toLocaleTimeString('fr-FR', {
                    hour: '2-digit',
                    minute: '2-digit'
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Bottom accent line */}
      <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-red-600 to-transparent opacity-60" />
    </header>
  );
}