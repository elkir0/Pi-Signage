'use client';

import React from 'react';
import { Activity } from 'lucide-react';
import Image from 'next/image';

export default function Header() {
  return (
    <header className="bg-black border-b-2 border-red-600 shadow-lg shadow-red-600/20">
      <div className="container mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="relative w-12 h-12">
              <Image 
                src="/pisignage-logo.png" 
                alt="PiSignage Logo" 
                width={48}
                height={48}
                className="object-contain"
                priority
              />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gradient-free">
                PiSignage
              </h1>
              <p className="text-xs text-gray-400">Digital Signage System v2.0</p>
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <Activity className="w-4 h-4 text-green-500 animate-pulse" />
              <span className="text-sm text-gray-400">Système actif</span>
            </div>
            <div className="text-sm text-gray-500">
              {new Date().toLocaleDateString('fr-FR', { 
                day: 'numeric', 
                month: 'long', 
                year: 'numeric' 
              })}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}