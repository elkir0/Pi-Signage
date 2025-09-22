'use client';

import React, { useState } from 'react';
import { Calendar, Clock, Plus, Trash2, Save, Play } from 'lucide-react';

interface ScheduleItem {
  id: string;
  name: string;
  playlistId: string;
  startTime: string;
  endTime: string;
  days: string[];
  enabled: boolean;
}

export default function Schedule() {
  const [schedules, setSchedules] = useState<ScheduleItem[]>([]);
  const [showAddForm, setShowAddForm] = useState(false);
  const [newSchedule, setNewSchedule] = useState<Partial<ScheduleItem>>({
    name: '',
    playlistId: '',
    startTime: '09:00',
    endTime: '18:00',
    days: [],
    enabled: true
  });

  const daysOfWeek = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  const playlists = [
    { id: '1', name: 'Playlist Matinale' },
    { id: '2', name: 'Playlist Soirée' },
    { id: '3', name: 'Playlist Weekend' }
  ];

  const addSchedule = () => {
    if (newSchedule.name && newSchedule.playlistId && newSchedule.days?.length) {
      const schedule: ScheduleItem = {
        id: Date.now().toString(),
        name: newSchedule.name,
        playlistId: newSchedule.playlistId,
        startTime: newSchedule.startTime || '09:00',
        endTime: newSchedule.endTime || '18:00',
        days: newSchedule.days,
        enabled: newSchedule.enabled ?? true
      };
      setSchedules([...schedules, schedule]);
      setNewSchedule({
        name: '',
        playlistId: '',
        startTime: '09:00',
        endTime: '18:00',
        days: [],
        enabled: true
      });
      setShowAddForm(false);
    }
  };

  const toggleDay = (day: string) => {
    const days = newSchedule.days || [];
    if (days.includes(day)) {
      setNewSchedule({ ...newSchedule, days: days.filter(d => d !== day) });
    } else {
      setNewSchedule({ ...newSchedule, days: [...days, day] });
    }
  };

  const deleteSchedule = (id: string) => {
    setSchedules(schedules.filter(s => s.id !== id));
  };

  const toggleSchedule = (id: string) => {
    setSchedules(schedules.map(s => 
      s.id === id ? { ...s, enabled: !s.enabled } : s
    ));
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold ps-gradient-text">
            Programmation
          </h1>
          <p className="text-gray-400 mt-1">Gérez vos playlists programmées</p>
        </div>
        <button
          onClick={() => setShowAddForm(true)}
          className="ps-btn-secondary flex items-center gap-2"
        >
          <Plus className="w-4 h-4" />
          Nouvelle programmation
        </button>
      </div>

      {/* Add Schedule Form */}
      {showAddForm && (
        <div className="ps-card-accent ps-animate-fade-in">
          <h3 className="text-xl font-semibold text-red-500 mb-4">
            Nouvelle programmation
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">
                Nom de la programmation
              </label>
              <input
                type="text"
                value={newSchedule.name}
                onChange={(e) => setNewSchedule({ ...newSchedule, name: e.target.value })}
                className="ps-input w-full"
                placeholder="Ex: Horaires bureau"
              />
            </div>
            
            <div>
              <label className="block text-sm text-gray-400 mb-2">
                Playlist
              </label>
              <select
                value={newSchedule.playlistId}
                onChange={(e) => setNewSchedule({ ...newSchedule, playlistId: e.target.value })}
                className="ps-input w-full"
              >
                <option value="">Sélectionner une playlist</option>
                {playlists.map(p => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            </div>
            
            <div>
              <label className="block text-sm text-gray-400 mb-2">
                Heure de début
              </label>
              <input
                type="time"
                value={newSchedule.startTime}
                onChange={(e) => setNewSchedule({ ...newSchedule, startTime: e.target.value })}
                className="ps-input w-full"
              />
            </div>
            
            <div>
              <label className="block text-sm text-gray-400 mb-2">
                Heure de fin
              </label>
              <input
                type="time"
                value={newSchedule.endTime}
                onChange={(e) => setNewSchedule({ ...newSchedule, endTime: e.target.value })}
                className="ps-input w-full"
              />
            </div>
          </div>
          
          <div className="mt-4">
            <label className="block text-sm text-gray-400 mb-2">
              Jours actifs
            </label>
            <div className="flex gap-2">
              {daysOfWeek.map(day => (
                <button
                  key={day}
                  onClick={() => toggleDay(day)}
                  className={`px-3 py-1 rounded border transition-all ${
                    newSchedule.days?.includes(day)
                      ? 'bg-red-600 border-red-600 text-white'
                      : 'border-gray-600 text-gray-400 hover:border-red-600'
                  }`}
                >
                  {day}
                </button>
              ))}
            </div>
          </div>
          
          <div className="flex gap-2 mt-6">
            <button
              onClick={addSchedule}
              className="ps-btn-secondary flex items-center gap-2"
            >
              <Save className="w-4 h-4" />
              Enregistrer
            </button>
            <button
              onClick={() => setShowAddForm(false)}
              className="px-4 py-2 border border-gray-600 text-gray-400 rounded hover:border-red-600 transition-colors"
            >
              Annuler
            </button>
          </div>
        </div>
      )}

      {/* Schedule List */}
      <div className="space-y-4">
        {schedules.length === 0 ? (
          <div className="ps-card-accent p-6 rounded-lg text-center py-12">
            <Calendar className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 mb-4">Aucune programmation configurée</p>
            <button
              onClick={() => setShowAddForm(true)}
              className="ps-btn-secondary inline-flex items-center gap-2"
            >
              <Plus className="w-4 h-4" />
              Créer votre première programmation
            </button>
          </div>
        ) : (
          schedules.map(schedule => (
            <div
              key={schedule.id}
              className={`ps-card-accent p-6 rounded-lg ${!schedule.enabled && 'opacity-50'}`}
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-semibold text-white">
                      {schedule.name}
                    </h3>
                    <span className={`px-2 py-1 rounded text-xs ${
                      schedule.enabled
                        ? 'bg-green-600/20 text-green-400'
                        : 'bg-gray-600/20 text-gray-400'
                    }`}>
                      {schedule.enabled ? 'Actif' : 'Inactif'}
                    </span>
                  </div>
                  
                  <div className="flex flex-wrap gap-4 text-sm text-gray-400">
                    <div className="flex items-center gap-1">
                      <Clock className="w-4 h-4" />
                      {schedule.startTime} - {schedule.endTime}
                    </div>
                    <div className="flex items-center gap-1">
                      <Play className="w-4 h-4" />
                      {playlists.find(p => p.id === schedule.playlistId)?.name}
                    </div>
                    <div className="flex gap-1">
                      {schedule.days.map(day => (
                        <span
                          key={day}
                          className="px-2 py-0.5 bg-red-600/20 text-red-400 rounded text-xs"
                        >
                          {day}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => toggleSchedule(schedule.id)}
                    className={`px-3 py-1 rounded text-sm transition-colors ${
                      schedule.enabled
                        ? 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                        : 'bg-green-600 text-white hover:bg-green-700'
                    }`}
                  >
                    {schedule.enabled ? 'Désactiver' : 'Activer'}
                  </button>
                  <button
                    onClick={() => deleteSchedule(schedule.id)}
                    className="p-2 text-red-400 hover:text-red-300 transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Info Section */}
      <div className="ps-card-accent bg-gradient-to-r from-gray-900 to-gray-800 border-yellow-600/50">
        <div className="flex items-start gap-3">
          <Clock className="w-5 h-5 text-yellow-500 mt-0.5" />
          <div>
            <h4 className="font-semibold text-yellow-400 mb-1">
              Note importante
            </h4>
            <p className="text-sm text-gray-300">
              Les programmations nécessitent la configuration d'un service cron sur le système. 
              Consultez la documentation pour activer le scheduling automatique.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}