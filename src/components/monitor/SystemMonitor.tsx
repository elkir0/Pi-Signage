'use client';

import React, { useState, useEffect } from 'react';
import { Activity, HardDrive, Cpu, Thermometer, Wifi, Clock, AlertTriangle, CheckCircle, XCircle, RefreshCw } from 'lucide-react';

interface LogEntry {
  timestamp: string;
  level: 'info' | 'warning' | 'error';
  message: string;
}

interface SystemMetrics {
  cpu: number[];
  memory: number[];
  temperature: number[];
  timestamps: string[];
}

export default function SystemMonitor() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [metrics, setMetrics] = useState<SystemMetrics>({
    cpu: [],
    memory: [],
    temperature: [],
    timestamps: []
  });
  const [filter, setFilter] = useState<'all' | 'info' | 'warning' | 'error'>('all');
  const [autoRefresh, setAutoRefresh] = useState(true);

  useEffect(() => {
    fetchLogs();
    fetchMetrics();
    
    if (autoRefresh) {
      const interval = setInterval(() => {
        fetchLogs();
        fetchMetrics();
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [autoRefresh]);

  const fetchLogs = async () => {
    try {
      const response = await fetch('/api/system/logs');
      const data = await response.json();
      setLogs(data);
    } catch (error) {
      console.error('Failed to fetch logs:', error);
    }
  };

  const fetchMetrics = async () => {
    try {
      const response = await fetch('/api/system/metrics');
      const data = await response.json();
      
      setMetrics(prev => ({
        cpu: [...prev.cpu.slice(-19), data.cpu],
        memory: [...prev.memory.slice(-19), data.memory],
        temperature: [...prev.temperature.slice(-19), data.temperature],
        timestamps: [...prev.timestamps.slice(-19), new Date().toLocaleTimeString()]
      }));
    } catch (error) {
      console.error('Failed to fetch metrics:', error);
    }
  };

  const clearLogs = async () => {
    if (confirm('Êtes-vous sûr de vouloir effacer tous les logs?')) {
      try {
        await fetch('/api/system/logs', { method: 'DELETE' });
        setLogs([]);
      } catch (error) {
        console.error('Failed to clear logs:', error);
      }
    }
  };

  const filteredLogs = logs.filter(log => 
    filter === 'all' || log.level === filter
  );

  const getLogIcon = (level: string) => {
    switch (level) {
      case 'error':
        return <XCircle className="w-4 h-4 text-red-500" />;
      case 'warning':
        return <AlertTriangle className="w-4 h-4 text-yellow-500" />;
      default:
        return <CheckCircle className="w-4 h-4 text-green-500" />;
    }
  };

  const getMetricColor = (value: number, type: 'cpu' | 'memory' | 'temperature') => {
    if (type === 'temperature') {
      if (value > 70) return 'text-red-500';
      if (value > 50) return 'text-yellow-500';
      return 'text-green-500';
    }
    if (value > 80) return 'text-red-500';
    if (value > 60) return 'text-yellow-500';
    return 'text-green-500';
  };

  // Generate simple ASCII graph
  const generateGraph = (data: number[], max: number = 100) => {
    const height = 5;
    const width = data.length;
    const graph: string[][] = Array(height).fill(null).map(() => Array(width).fill(' '));
    
    data.forEach((value, i) => {
      const scaledHeight = Math.round((value / max) * (height - 1));
      for (let j = 0; j < scaledHeight + 1; j++) {
        graph[height - 1 - j][i] = '█';
      }
    });
    
    return graph.map(row => row.join('')).join('\n');
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gradient-free">
            Monitoring Système
          </h1>
          <p className="text-gray-400 mt-1">Surveillance en temps réel</p>
        </div>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-gray-400">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="w-4 h-4 accent-red-600"
            />
            Actualisation auto
          </label>
          <button
            onClick={() => {
              fetchLogs();
              fetchMetrics();
            }}
            className="btn-free p-2"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm flex items-center gap-2">
              <Cpu className="w-4 h-4 text-red-500" />
              CPU
            </span>
            <span className={`text-2xl font-bold ${getMetricColor(metrics.cpu[metrics.cpu.length - 1] || 0, 'cpu')}`}>
              {(metrics.cpu[metrics.cpu.length - 1] || 0).toFixed(1)}%
            </span>
          </div>
          <div className="text-xs font-mono text-green-400 h-20 flex items-end">
            <pre className="w-full">{generateGraph(metrics.cpu)}</pre>
          </div>
        </div>

        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm flex items-center gap-2">
              <HardDrive className="w-4 h-4 text-red-500" />
              Mémoire
            </span>
            <span className={`text-2xl font-bold ${getMetricColor(metrics.memory[metrics.memory.length - 1] || 0, 'memory')}`}>
              {(metrics.memory[metrics.memory.length - 1] || 0).toFixed(1)}%
            </span>
          </div>
          <div className="text-xs font-mono text-blue-400 h-20 flex items-end">
            <pre className="w-full">{generateGraph(metrics.memory)}</pre>
          </div>
        </div>

        <div className="card-free">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm flex items-center gap-2">
              <Thermometer className="w-4 h-4 text-red-500" />
              Température
            </span>
            <span className={`text-2xl font-bold ${getMetricColor(metrics.temperature[metrics.temperature.length - 1] || 0, 'temperature')}`}>
              {(metrics.temperature[metrics.temperature.length - 1] || 0).toFixed(1)}°C
            </span>
          </div>
          <div className="text-xs font-mono text-red-400 h-20 flex items-end">
            <pre className="w-full">{generateGraph(metrics.temperature, 100)}</pre>
          </div>
        </div>
      </div>

      {/* Logs Section */}
      <div className="card-free">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold text-red-500 flex items-center gap-2">
            <Activity className="w-5 h-5" />
            Logs Système
          </h2>
          <div className="flex gap-2">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as any)}
              className="input-free px-3 py-1 rounded text-sm"
            >
              <option value="all">Tous</option>
              <option value="info">Info</option>
              <option value="warning">Avertissement</option>
              <option value="error">Erreur</option>
            </select>
            <button
              onClick={clearLogs}
              className="text-gray-400 hover:text-red-400 transition-colors text-sm"
            >
              Effacer
            </button>
          </div>
        </div>

        <div className="bg-black rounded border border-gray-800 p-3 max-h-96 overflow-y-auto scrollbar-thin">
          {filteredLogs.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              Aucun log disponible
            </div>
          ) : (
            <div className="space-y-1">
              {filteredLogs.map((log, index) => (
                <div
                  key={index}
                  className="flex items-start gap-2 py-1 font-mono text-xs hover:bg-gray-900/50 rounded px-2"
                >
                  {getLogIcon(log.level)}
                  <span className="text-gray-500">{log.timestamp}</span>
                  <span className={`flex-1 ${
                    log.level === 'error' ? 'text-red-400' :
                    log.level === 'warning' ? 'text-yellow-400' :
                    'text-gray-300'
                  }`}>
                    {log.message}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* System Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="card-free">
          <h3 className="text-lg font-semibold text-red-500 mb-3 flex items-center gap-2">
            <Wifi className="w-5 h-5" />
            Services
          </h3>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">VLC Media Player</span>
              <span className="text-green-400">● Actif</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Node.js Server</span>
              <span className="text-green-400">● Actif</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Cron Scheduler</span>
              <span className="text-yellow-400">● En pause</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">SSH</span>
              <span className="text-green-400">● Actif</span>
            </div>
          </div>
        </div>

        <div className="card-free">
          <h3 className="text-lg font-semibold text-red-500 mb-3 flex items-center gap-2">
            <Clock className="w-5 h-5" />
            Statistiques
          </h3>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Temps de fonctionnement</span>
              <span className="text-white">2j 14h 32m</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Médias lus aujourd'hui</span>
              <span className="text-white">127</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Erreurs (24h)</span>
              <span className="text-white">3</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Dernière mise à jour</span>
              <span className="text-white">Il y a 5 min</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}