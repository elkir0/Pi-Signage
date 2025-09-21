'use client'

import React, { useState, useEffect, useCallback } from 'react'
import { 
  Play, 
  Pause, 
  Plus, 
  Save, 
  Trash2, 
  Image, 
  Film, 
  Music, 
  Clock, 
  GripVertical,
  Download,
  Upload,
  Shuffle,
  Repeat,
  Settings
} from 'lucide-react'

interface MediaFile {
  id: string
  name: string
  type: 'video' | 'image' | 'audio' | 'unknown'
  size: number
  path: string
  thumbnail: string
  duration?: number
}

interface PlaylistItem {
  id: string
  mediaId: string
  name: string
  type: string
  duration?: number
  imageDuration?: number // For images, custom display duration
  order: number
}

interface Playlist {
  id: string
  name: string
  items: PlaylistItem[]
  settings: {
    loop: boolean
    shuffle: boolean
    transition: string
    defaultImageDuration: number
  }
  createdAt: string
  updatedAt: string
}

export default function PlaylistManager() {
  const [mediaLibrary, setMediaLibrary] = useState<MediaFile[]>([])
  const [playlists, setPlaylists] = useState<Playlist[]>([])
  const [currentPlaylist, setCurrentPlaylist] = useState<Playlist | null>(null)
  const [selectedMedia, setSelectedMedia] = useState<string[]>([])
  const [draggedItem, setDraggedItem] = useState<PlaylistItem | null>(null)
  const [draggedMedia, setDraggedMedia] = useState<MediaFile | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showSettings, setShowSettings] = useState(false)

  // Fetch data on component mount
  useEffect(() => {
    fetchMediaLibrary()
    fetchPlaylists()
  }, [])

  const fetchMediaLibrary = async () => {
    try {
      const response = await fetch('/api/media')
      if (!response.ok) throw new Error('Failed to fetch media')
      const data = await response.json()
      setMediaLibrary(data.media || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load media library')
    }
  }

  const fetchPlaylists = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/playlist')
      if (!response.ok) throw new Error('Failed to fetch playlists')
      const data = await response.json()
      setPlaylists(data.playlists || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load playlists')
    } finally {
      setLoading(false)
    }
  }

  const createNewPlaylist = () => {
    const newPlaylist: Playlist = {
      id: `temp_${Date.now()}`,
      name: 'New Playlist',
      items: [],
      settings: {
        loop: true,
        shuffle: false,
        transition: 'fade',
        defaultImageDuration: 5
      },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
    setCurrentPlaylist(newPlaylist)
  }

  const savePlaylist = async () => {
    if (!currentPlaylist) return

    setSaving(true)
    setError(null)

    try {
      const isNew = currentPlaylist.id.startsWith('temp_')
      const method = isNew ? 'POST' : 'PUT'
      const url = isNew ? '/api/playlist' : `/api/playlist?id=${currentPlaylist.id}`

      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: currentPlaylist.name,
          items: currentPlaylist.items,
          settings: currentPlaylist.settings
        })
      })

      if (!response.ok) throw new Error('Failed to save playlist')

      const savedPlaylist = await response.json()
      
      if (isNew) {
        setPlaylists(prev => [...prev, savedPlaylist])
        setCurrentPlaylist(savedPlaylist)
      } else {
        setPlaylists(prev => prev.map(p => p.id === savedPlaylist.id ? savedPlaylist : p))
        setCurrentPlaylist(savedPlaylist)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save playlist')
    } finally {
      setSaving(false)
    }
  }

  const deletePlaylist = async (playlistId: string) => {
    if (!confirm('Are you sure you want to delete this playlist?')) return

    try {
      const response = await fetch(`/api/playlist?id=${playlistId}`, {
        method: 'DELETE'
      })

      if (!response.ok) throw new Error('Failed to delete playlist')

      setPlaylists(prev => prev.filter(p => p.id !== playlistId))
      if (currentPlaylist?.id === playlistId) {
        setCurrentPlaylist(null)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete playlist')
    }
  }

  const addMediaToPlaylist = (media: MediaFile) => {
    if (!currentPlaylist) return

    const newItem: PlaylistItem = {
      id: `item_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      mediaId: media.id,
      name: media.name,
      type: media.type,
      duration: media.duration,
      imageDuration: media.type === 'image' ? currentPlaylist.settings.defaultImageDuration : undefined,
      order: currentPlaylist.items.length
    }

    setCurrentPlaylist(prev => prev ? {
      ...prev,
      items: [...prev.items, newItem],
      updatedAt: new Date().toISOString()
    } : null)
  }

  const removeItemFromPlaylist = (itemId: string) => {
    if (!currentPlaylist) return

    setCurrentPlaylist(prev => prev ? {
      ...prev,
      items: prev.items.filter(item => item.id !== itemId).map((item, index) => ({
        ...item,
        order: index
      })),
      updatedAt: new Date().toISOString()
    } : null)
  }

  const updateItemDuration = (itemId: string, duration: number) => {
    if (!currentPlaylist) return

    setCurrentPlaylist(prev => prev ? {
      ...prev,
      items: prev.items.map(item => 
        item.id === itemId ? { ...item, imageDuration: duration } : item
      ),
      updatedAt: new Date().toISOString()
    } : null)
  }

  const reorderItems = (dragIndex: number, hoverIndex: number) => {
    if (!currentPlaylist) return

    const dragItem = currentPlaylist.items[dragIndex]
    const newItems = [...currentPlaylist.items]
    newItems.splice(dragIndex, 1)
    newItems.splice(hoverIndex, 0, dragItem)

    setCurrentPlaylist(prev => prev ? {
      ...prev,
      items: newItems.map((item, index) => ({ ...item, order: index })),
      updatedAt: new Date().toISOString()
    } : null)
  }

  const getMediaIcon = (type: string) => {
    switch (type) {
      case 'video':
        return <Film className="w-4 h-4 text-red-500" />
      case 'image':
        return <Image className="w-4 h-4 text-red-500" />
      case 'audio':
        return <Music className="w-4 h-4 text-red-500" />
      default:
        return <Film className="w-4 h-4 text-red-500" />
    }
  }

  const formatDuration = (seconds?: number): string => {
    if (!seconds) return 'Unknown'
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  const getTotalDuration = (): number => {
    if (!currentPlaylist) return 0
    
    return currentPlaylist.items.reduce((total, item) => {
      if (item.type === 'image') {
        return total + (item.imageDuration || currentPlaylist.settings.defaultImageDuration)
      }
      return total + (item.duration || 0)
    }, 0)
  }

  const exportPlaylist = () => {
    if (!currentPlaylist) return

    const dataStr = JSON.stringify(currentPlaylist, null, 2)
    const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr)
    
    const exportFileDefaultName = `${currentPlaylist.name.replace(/[^a-z0-9]/gi, '_').toLowerCase()}.json`
    
    const linkElement = document.createElement('a')
    linkElement.setAttribute('href', dataUri)
    linkElement.setAttribute('download', exportFileDefaultName)
    linkElement.click()
  }

  const importPlaylist = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const playlist = JSON.parse(e.target?.result as string)
        playlist.id = `temp_${Date.now()}`
        playlist.updatedAt = new Date().toISOString()
        setCurrentPlaylist(playlist)
      } catch (err) {
        setError('Invalid playlist file')
      }
    }
    reader.readAsText(file)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 bg-black rounded-lg border border-red-600">
        <div className="text-white">Loading playlist manager...</div>
      </div>
    )
  }

  return (
    <div className="bg-black rounded-lg border border-red-600 p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold text-white flex items-center gap-3">
          <Play className="w-8 h-8 text-red-500" />
          Playlist Manager
        </h2>
        
        <div className="flex items-center gap-3">
          <label className="bg-gray-700 hover:bg-gray-600 text-white px-3 py-2 rounded-lg cursor-pointer transition-colors text-sm flex items-center gap-2">
            <Upload className="w-4 h-4" />
            Import
            <input
              type="file"
              accept=".json"
              className="hidden"
              onChange={importPlaylist}
            />
          </label>
          
          <button
            onClick={exportPlaylist}
            disabled={!currentPlaylist}
            className="bg-gray-700 hover:bg-gray-600 disabled:bg-gray-800 disabled:cursor-not-allowed text-white px-3 py-2 rounded-lg transition-colors text-sm flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export
          </button>
          
          <button
            onClick={createNewPlaylist}
            className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg transition-colors flex items-center gap-2"
          >
            <Plus className="w-4 h-4" />
            New Playlist
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-900 border border-red-600 text-white p-3 rounded-lg mb-4">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Existing Playlists */}
        <div className="bg-gray-900 rounded-lg p-4">
          <h3 className="text-white font-medium mb-3">Saved Playlists</h3>
          <div className="space-y-2">
            {playlists.map((playlist) => (
              <div
                key={playlist.id}
                className={`bg-gray-800 rounded p-3 cursor-pointer transition-colors border ${
                  currentPlaylist?.id === playlist.id 
                    ? 'border-red-500 bg-red-900/20' 
                    : 'border-gray-700 hover:border-red-500'
                }`}
                onClick={() => setCurrentPlaylist(playlist)}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white font-medium">{playlist.name}</p>
                    <p className="text-gray-400 text-sm">
                      {playlist.items.length} items
                    </p>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      deletePlaylist(playlist.id)
                    }}
                    className="text-red-500 hover:text-red-400"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
            
            {playlists.length === 0 && (
              <div className="text-center py-6">
                <Play className="w-8 h-8 text-gray-600 mx-auto mb-2" />
                <p className="text-gray-400 text-sm">No playlists created yet</p>
              </div>
            )}
          </div>
        </div>

        {/* Media Library */}
        <div className="bg-gray-900 rounded-lg p-4">
          <h3 className="text-white font-medium mb-3">Media Library</h3>
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {mediaLibrary.map((media) => (
              <div
                key={media.id}
                draggable
                onDragStart={() => setDraggedMedia(media)}
                onDragEnd={() => setDraggedMedia(null)}
                className="bg-gray-800 rounded p-2 cursor-move hover:bg-gray-700 transition-colors flex items-center gap-3"
                onClick={() => currentPlaylist && addMediaToPlaylist(media)}
              >
                <img
                  src={media.thumbnail}
                  alt={media.name}
                  className="w-8 h-8 object-cover rounded"
                  onError={(e) => {
                    const target = e.target as HTMLImageElement
                    target.style.display = 'none'
                  }}
                />
                {getMediaIcon(media.type)}
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm truncate">{media.name}</p>
                  <p className="text-gray-400 text-xs">{media.type}</p>
                </div>
              </div>
            ))}
            
            {mediaLibrary.length === 0 && (
              <div className="text-center py-6">
                <Film className="w-8 h-8 text-gray-600 mx-auto mb-2" />
                <p className="text-gray-400 text-sm">No media files available</p>
              </div>
            )}
          </div>
        </div>

        {/* Current Playlist Editor */}
        <div className="bg-gray-900 rounded-lg p-4">
          {currentPlaylist ? (
            <>
              <div className="flex items-center justify-between mb-4">
                <input
                  type="text"
                  value={currentPlaylist.name}
                  onChange={(e) => setCurrentPlaylist(prev => prev ? {
                    ...prev,
                    name: e.target.value,
                    updatedAt: new Date().toISOString()
                  } : null)}
                  className="bg-gray-800 border border-gray-600 text-white px-2 py-1 rounded text-sm flex-1 mr-2 focus:outline-none focus:border-red-500"
                />
                
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowSettings(!showSettings)}
                    className="text-gray-400 hover:text-white"
                  >
                    <Settings className="w-4 h-4" />
                  </button>
                  
                  <button
                    onClick={savePlaylist}
                    disabled={saving}
                    className="bg-red-600 hover:bg-red-700 disabled:bg-gray-600 text-white px-3 py-1 rounded text-sm transition-colors flex items-center gap-1"
                  >
                    <Save className="w-3 h-3" />
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                </div>
              </div>

              {/* Playlist Settings */}
              {showSettings && (
                <div className="bg-gray-800 rounded p-3 mb-4 space-y-3">
                  <div className="flex items-center gap-4">
                    <label className="flex items-center gap-2 text-white text-sm">
                      <input
                        type="checkbox"
                        checked={currentPlaylist.settings.loop}
                        onChange={(e) => setCurrentPlaylist(prev => prev ? {
                          ...prev,
                          settings: { ...prev.settings, loop: e.target.checked }
                        } : null)}
                        className="w-4 h-4 text-red-600 bg-gray-800 border-gray-600 rounded"
                      />
                      <Repeat className="w-4 h-4" />
                      Loop
                    </label>
                    
                    <label className="flex items-center gap-2 text-white text-sm">
                      <input
                        type="checkbox"
                        checked={currentPlaylist.settings.shuffle}
                        onChange={(e) => setCurrentPlaylist(prev => prev ? {
                          ...prev,
                          settings: { ...prev.settings, shuffle: e.target.checked }
                        } : null)}
                        className="w-4 h-4 text-red-600 bg-gray-800 border-gray-600 rounded"
                      />
                      <Shuffle className="w-4 h-4" />
                      Shuffle
                    </label>
                  </div>
                  
                  <div className="flex items-center gap-2">
                    <Clock className="w-4 h-4 text-gray-400" />
                    <label className="text-white text-sm">Image Duration:</label>
                    <input
                      type="number"
                      min="1"
                      max="300"
                      value={currentPlaylist.settings.defaultImageDuration}
                      onChange={(e) => setCurrentPlaylist(prev => prev ? {
                        ...prev,
                        settings: { ...prev.settings, defaultImageDuration: Number(e.target.value) }
                      } : null)}
                      className="bg-gray-700 border border-gray-600 text-white px-2 py-1 rounded text-sm w-16 focus:outline-none focus:border-red-500"
                    />
                    <span className="text-gray-400 text-sm">seconds</span>
                  </div>
                </div>
              )}

              {/* Playlist Items */}
              <div
                className="space-y-2 max-h-80 overflow-y-auto"
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault()
                  if (draggedMedia) {
                    addMediaToPlaylist(draggedMedia)
                    setDraggedMedia(null)
                  }
                }}
              >
                {currentPlaylist.items.map((item, index) => (
                  <div
                    key={item.id}
                    draggable
                    onDragStart={() => setDraggedItem(item)}
                    onDragEnd={() => setDraggedItem(null)}
                    className="bg-gray-800 rounded p-2 flex items-center gap-2 hover:bg-gray-700 transition-colors"
                  >
                    <GripVertical className="w-4 h-4 text-gray-500 cursor-move" />
                    {getMediaIcon(item.type)}
                    
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-sm truncate">{item.name}</p>
                      <div className="flex items-center gap-2">
                        {item.type === 'image' ? (
                          <div className="flex items-center gap-1">
                            <Clock className="w-3 h-3 text-gray-400" />
                            <input
                              type="number"
                              min="1"
                              max="300"
                              value={item.imageDuration || currentPlaylist.settings.defaultImageDuration}
                              onChange={(e) => updateItemDuration(item.id, Number(e.target.value))}
                              className="bg-gray-700 border border-gray-600 text-white px-1 py-0 rounded text-xs w-12 focus:outline-none focus:border-red-500"
                            />
                            <span className="text-gray-400 text-xs">s</span>
                          </div>
                        ) : (
                          <span className="text-gray-400 text-xs">
                            {formatDuration(item.duration)}
                          </span>
                        )}
                      </div>
                    </div>
                    
                    <button
                      onClick={() => removeItemFromPlaylist(item.id)}
                      className="text-red-500 hover:text-red-400"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
                
                {currentPlaylist.items.length === 0 && (
                  <div className="border-2 border-dashed border-gray-600 rounded-lg p-6 text-center">
                    <Play className="w-8 h-8 text-gray-600 mx-auto mb-2" />
                    <p className="text-gray-400 text-sm">Drag media here or click from library</p>
                  </div>
                )}
              </div>

              {/* Playlist Info */}
              {currentPlaylist.items.length > 0 && (
                <div className="mt-4 pt-3 border-t border-gray-700">
                  <div className="flex justify-between text-sm text-gray-400">
                    <span>{currentPlaylist.items.length} items</span>
                    <span>Total: {formatDuration(getTotalDuration())}</span>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="text-center py-12">
              <Plus className="w-12 h-12 text-gray-600 mx-auto mb-3" />
              <p className="text-gray-400 mb-2">No playlist selected</p>
              <p className="text-gray-500 text-sm">Create a new playlist or select an existing one</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}