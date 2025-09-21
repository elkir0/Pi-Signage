'use client';

import React, { useState, useEffect } from 'react';
import { Save, Download, Upload, Wifi, Monitor, Volume2, Clock, RefreshCw, AlertCircle, CheckCircle } from 'lucide-react';

interface SettingsData {
  display: {
    resolution: string;
    orientation: 'landscape' | 'portrait';
    brightness: number;
  };
  network: {
    wifi: {
      ssid: string;
      password: string;
    };
  };
  system: {
    autoStart: boolean;
    defaultVolume: number;
    screensaverTimeout: number;
    debugMode: boolean;
  };
  media: {
    defaultImageDuration: number;
    videoQuality: string;
    cacheEnabled: boolean;
  };
}

export default function Settings() {
  const [settings, setSettings] = useState<SettingsData>({
    display: {
      resolution: '1920x1080',
      orientation: 'landscape',
      brightness: 100
    },
    network: {
      wifi: {
        ssid: '',
        password: ''
      }
    },
    system: {
      autoStart: true,
      defaultVolume: 50,
      screensaverTimeout: 0,
      debugMode: false
    },
    media: {
      defaultImageDuration: 10,
      videoQuality: '720p',
      cacheEnabled: true
    }
  });
  
  const [saveStatus, setSaveStatus] = useState<'idle' | 'saving' | 'success' | 'error'>('idle');
  const [wifiNetworks, setWifiNetworks] = useState<string[]>([]);

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      const response = await fetch('/api/settings');
      if (response.ok) {
        const data = await response.json();
        setSettings(data);
      }
    } catch (error) {
      console.error('Failed to load settings:', error);
    }
  };

  const saveSettings = async () => {
    setSaveStatus('saving');
    try {
      const response = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
      });
      
      if (response.ok) {
        setSaveStatus('success');
        setTimeout(() => setSaveStatus('idle'), 3000);
      } else {
        setSaveStatus('error');
      }
    } catch (error) {
      console.error('Failed to save settings:', error);
      setSaveStatus('error');
    }
  };

  const exportSettings = () => {
    const dataStr = JSON.stringify(settings, null, 2);
    const dataUri = 'data:application/json;charset=utf-8,' + encodeURIComponent(dataStr);
    const exportFileDefaultName = `pisignage-settings-${Date.now()}.json`;
    
    const linkElement = document.createElement('a');
    linkElement.setAttribute('href', dataUri);
    linkElement.setAttribute('download', exportFileDefaultName);
    linkElement.click();
  };

  const importSettings = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const imported = JSON.parse(e.target?.result as string);
          setSettings(imported);
          setSaveStatus('success');
          setTimeout(() => setSaveStatus('idle'), 3000);
        } catch (error) {
          console.error('Invalid settings file:', error);
          setSaveStatus('error');
        }
      };
      reader.readAsText(file);
    }
  };

  const scanWifiNetworks = async () => {
    try {
      const response = await fetch('/api/system/wifi-scan');
      const networks = await response.json();
      setWifiNetworks(networks);
    } catch (error) {
      console.error('Failed to scan WiFi networks:', error);
    }
  };

  const restartSystem = async () => {
    if (confirm('Êtes-vous sûr de vouloir redémarrer le système?')) {
      try {
        await fetch('/api/system/restart', { method: 'POST' });
      } catch (error) {
        console.error('Failed to restart:', error);
      }
    }
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold text-gradient-free mb-2">
          Paramètres Système
        </h1>
        <p className="text-gray-400">Configuration de PiSignage</p>
      </div>

      {/* Display Settings */}
      <div className="card-free">
        <h2 className="text-xl font-semibold text-red-500 mb-4 flex items-center gap-2">
          <Monitor className="w-5 h-5" />
          Affichage
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Résolution
            </label>
            <select
              value={settings.display.resolution}
              onChange={(e) => setSettings({
                ...settings,
                display: { ...settings.display, resolution: e.target.value }
              })}
              className="input-free w-full px-3 py-2 rounded"
            >
              <option value="1920x1080">1920x1080 (Full HD)</option>
              <option value="1280x720">1280x720 (HD)</option>
              <option value="3840x2160">3840x2160 (4K)</option>
              <option value="1024x768">1024x768</option>
            </select>
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Orientation
            </label>
            <select
              value={settings.display.orientation}
              onChange={(e) => setSettings({
                ...settings,
                display: { ...settings.display, orientation: e.target.value as 'landscape' | 'portrait' }
              })}
              className="input-free w-full px-3 py-2 rounded"
            >
              <option value="landscape">Paysage</option>
              <option value="portrait">Portrait</option>
            </select>
          </div>
          
          <div className="md:col-span-2">
            <label className="block text-sm text-gray-400 mb-2">
              Luminosité: {settings.display.brightness}%
            </label>
            <input
              type="range"
              min="10"
              max="100"
              value={settings.display.brightness}
              onChange={(e) => setSettings({
                ...settings,
                display: { ...settings.display, brightness: Number(e.target.value) }
              })}
              className="w-full accent-red-600"
            />
          </div>
        </div>
      </div>

      {/* Network Settings */}
      <div className="card-free">
        <h2 className="text-xl font-semibold text-red-500 mb-4 flex items-center gap-2">
          <Wifi className="w-5 h-5" />
          Réseau
        </h2>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Réseau WiFi
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                value={settings.network.wifi.ssid}
                onChange={(e) => setSettings({
                  ...settings,
                  network: { 
                    ...settings.network,
                    wifi: { ...settings.network.wifi, ssid: e.target.value }
                  }
                })}
                placeholder="SSID"
                className="input-free flex-1 px-3 py-2 rounded"
              />
              <button
                onClick={scanWifiNetworks}
                className="btn-free"
              >
                Scanner
              </button>
            </div>
            
            {wifiNetworks.length > 0 && (
              <select
                onChange={(e) => setSettings({
                  ...settings,
                  network: { 
                    ...settings.network,
                    wifi: { ...settings.network.wifi, ssid: e.target.value }
                  }
                })}
                className="input-free w-full px-3 py-2 rounded mt-2"
              >
                <option value="">Sélectionner un réseau</option>
                {wifiNetworks.map(network => (
                  <option key={network} value={network}>{network}</option>
                ))}
              </select>
            )}
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Mot de passe WiFi
            </label>
            <input
              type="password"
              value={settings.network.wifi.password}
              onChange={(e) => setSettings({
                ...settings,
                network: { 
                  ...settings.network,
                  wifi: { ...settings.network.wifi, password: e.target.value }
                }
              })}
              placeholder="Mot de passe"
              className="input-free w-full px-3 py-2 rounded"
            />
          </div>
        </div>
      </div>

      {/* System Settings */}
      <div className="card-free">
        <h2 className="text-xl font-semibold text-red-500 mb-4 flex items-center gap-2">
          <Clock className="w-5 h-5" />
          Système
        </h2>
        
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <label className="text-sm text-gray-400">
              Démarrage automatique
            </label>
            <input
              type="checkbox"
              checked={settings.system.autoStart}
              onChange={(e) => setSettings({
                ...settings,
                system: { ...settings.system, autoStart: e.target.checked }
              })}
              className="w-5 h-5 accent-red-600"
            />
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Volume par défaut: {settings.system.defaultVolume}%
            </label>
            <input
              type="range"
              min="0"
              max="100"
              value={settings.system.defaultVolume}
              onChange={(e) => setSettings({
                ...settings,
                system: { ...settings.system, defaultVolume: Number(e.target.value) }
              })}
              className="w-full accent-red-600"
            />
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Timeout écran de veille (minutes, 0 = désactivé)
            </label>
            <input
              type="number"
              min="0"
              max="60"
              value={settings.system.screensaverTimeout}
              onChange={(e) => setSettings({
                ...settings,
                system: { ...settings.system, screensaverTimeout: Number(e.target.value) }
              })}
              className="input-free w-full px-3 py-2 rounded"
            />
          </div>
          
          <div className="flex items-center justify-between">
            <label className="text-sm text-gray-400">
              Mode debug
            </label>
            <input
              type="checkbox"
              checked={settings.system.debugMode}
              onChange={(e) => setSettings({
                ...settings,
                system: { ...settings.system, debugMode: e.target.checked }
              })}
              className="w-5 h-5 accent-red-600"
            />
          </div>
        </div>
      </div>

      {/* Media Settings */}
      <div className="card-free">
        <h2 className="text-xl font-semibold text-red-500 mb-4 flex items-center gap-2">
          <Volume2 className="w-5 h-5" />
          Médias
        </h2>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Durée par défaut des images (secondes)
            </label>
            <input
              type="number"
              min="1"
              max="300"
              value={settings.media.defaultImageDuration}
              onChange={(e) => setSettings({
                ...settings,
                media: { ...settings.media, defaultImageDuration: Number(e.target.value) }
              })}
              className="input-free w-full px-3 py-2 rounded"
            />
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Qualité vidéo par défaut
            </label>
            <select
              value={settings.media.videoQuality}
              onChange={(e) => setSettings({
                ...settings,
                media: { ...settings.media, videoQuality: e.target.value }
              })}
              className="input-free w-full px-3 py-2 rounded"
            >
              <option value="best">Meilleure</option>
              <option value="1080p">1080p</option>
              <option value="720p">720p</option>
              <option value="480p">480p</option>
              <option value="360p">360p</option>
            </select>
          </div>
          
          <div className="flex items-center justify-between">
            <label className="text-sm text-gray-400">
              Cache activé
            </label>
            <input
              type="checkbox"
              checked={settings.media.cacheEnabled}
              onChange={(e) => setSettings({
                ...settings,
                media: { ...settings.media, cacheEnabled: e.target.checked }
              })}
              className="w-5 h-5 accent-red-600"
            />
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex flex-wrap gap-3 justify-center">
        <button
          onClick={saveSettings}
          className="btn-free flex items-center gap-2"
          disabled={saveStatus === 'saving'}
        >
          {saveStatus === 'saving' ? (
            <RefreshCw className="w-4 h-4 animate-spin" />
          ) : saveStatus === 'success' ? (
            <CheckCircle className="w-4 h-4" />
          ) : saveStatus === 'error' ? (
            <AlertCircle className="w-4 h-4" />
          ) : (
            <Save className="w-4 h-4" />
          )}
          {saveStatus === 'saving' ? 'Enregistrement...' :
           saveStatus === 'success' ? 'Enregistré!' :
           saveStatus === 'error' ? 'Erreur' :
           'Enregistrer'}
        </button>
        
        <button
          onClick={exportSettings}
          className="btn-free flex items-center gap-2"
        >
          <Download className="w-4 h-4" />
          Exporter
        </button>
        
        <label className="btn-free flex items-center gap-2 cursor-pointer">
          <Upload className="w-4 h-4" />
          Importer
          <input
            type="file"
            accept=".json"
            onChange={importSettings}
            className="hidden"
          />
        </label>
        
        <button
          onClick={restartSystem}
          className="btn-free bg-orange-600 hover:bg-orange-700 flex items-center gap-2"
        >
          <RefreshCw className="w-4 h-4" />
          Redémarrer
        </button>
      </div>

      {/* Status Message */}
      {saveStatus !== 'idle' && (
        <div className={`text-center animate-fade-in ${
          saveStatus === 'success' ? 'text-green-400' :
          saveStatus === 'error' ? 'text-red-400' :
          'text-gray-400'
        }`}>
          {saveStatus === 'saving' && 'Enregistrement des paramètres...'}
          {saveStatus === 'success' && 'Paramètres enregistrés avec succès!'}
          {saveStatus === 'error' && 'Erreur lors de l\'enregistrement'}
        </div>
      )}
    </div>
  );
}