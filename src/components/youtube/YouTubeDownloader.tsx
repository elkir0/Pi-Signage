'use client'

import React, { useState, useEffect } from 'react'
import { Download, Youtube, Play, Clock, CheckCircle, XCircle, Trash2 } from 'lucide-react'

interface DownloadItem {
  id: string
  url: string
  title?: string
  quality: string
  status: 'pending' | 'downloading' | 'completed' | 'error'
  progress: number
  error?: string
  addedAt: string
}

interface VideoInfo {
  title: string
  duration: string
  thumbnail: string
  formats: Array<{
    quality: string
    ext: string
    filesize?: number
  }>
}

export default function YouTubeDownloader() {
  const [url, setUrl] = useState('')
  const [quality, setQuality] = useState('best')
  const [downloading, setDownloading] = useState(false)
  const [queue, setQueue] = useState<DownloadItem[]>([])
  const [videoInfo, setVideoInfo] = useState<VideoInfo | null>(null)
  const [loadingInfo, setLoadingInfo] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const qualities = [
    { value: 'best', label: 'Best Quality', description: 'Highest available quality' },
    { value: '1080p', label: '1080p HD', description: 'Full HD (1920x1080)' },
    { value: '720p', label: '720p HD', description: 'HD Ready (1280x720)' },
    { value: '480p', label: '480p', description: 'Standard Definition (854x480)' },
    { value: '360p', label: '360p', description: 'Mobile Quality (640x360)' },
    { value: 'worst', label: 'Lowest Quality', description: 'Smallest file size' }
  ]

  useEffect(() => {
    // Load queue from localStorage
    const savedQueue = localStorage.getItem('youtube-download-queue')
    if (savedQueue) {
      try {
        setQueue(JSON.parse(savedQueue))
      } catch (e) {
        console.error('Failed to load queue from localStorage:', e)
      }
    }
  }, [])

  useEffect(() => {
    // Save queue to localStorage
    localStorage.setItem('youtube-download-queue', JSON.stringify(queue))
  }, [queue])

  const isValidYouTubeUrl = (url: string): boolean => {
    const youtubeRegex = /^(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)/
    return youtubeRegex.test(url)
  }

  const extractVideoId = (url: string): string | null => {
    const match = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
    return match ? match[1] : null
  }

  const fetchVideoInfo = async (videoUrl: string) => {
    setLoadingInfo(true)
    setError(null)
    setVideoInfo(null)

    try {
      const response = await fetch('/api/youtube/info', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ url: videoUrl })
      })

      if (!response.ok) {
        throw new Error('Failed to fetch video information')
      }

      const data = await response.json()
      setVideoInfo(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch video info')
    } finally {
      setLoadingInfo(false)
    }
  }

  const handleUrlChange = (newUrl: string) => {
    setUrl(newUrl)
    setVideoInfo(null)
    setError(null)

    if (newUrl && isValidYouTubeUrl(newUrl)) {
      // Debounce the API call
      const timeoutId = setTimeout(() => {
        fetchVideoInfo(newUrl)
      }, 1000)

      return () => clearTimeout(timeoutId)
    }
  }

  const addToQueue = () => {
    if (!url || !isValidYouTubeUrl(url)) {
      setError('Please enter a valid YouTube URL')
      return
    }

    const downloadItem: DownloadItem = {
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      url,
      title: videoInfo?.title || extractVideoId(url) || 'Unknown Video',
      quality,
      status: 'pending',
      progress: 0,
      addedAt: new Date().toISOString()
    }

    setQueue(prev => [downloadItem, ...prev])
    setUrl('')
    setVideoInfo(null)
    
    // Start download immediately
    startDownload(downloadItem.id)
  }

  const startDownload = async (itemId: string) => {
    const item = queue.find(q => q.id === itemId)
    if (!item) return

    setQueue(prev => prev.map(q => 
      q.id === itemId ? { ...q, status: 'downloading' as const, progress: 0 } : q
    ))

    try {
      const response = await fetch('/api/youtube/download', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          url: item.url,
          quality: item.quality,
          id: itemId
        })
      })

      if (!response.ok) {
        throw new Error('Download failed')
      }

      // Simulate progress updates (in real implementation, this would come from SSE or polling)
      let progress = 0
      const progressInterval = setInterval(() => {
        progress += Math.random() * 15
        if (progress >= 100) {
          progress = 100
          clearInterval(progressInterval)
          setQueue(prev => prev.map(q => 
            q.id === itemId ? { ...q, status: 'completed' as const, progress: 100 } : q
          ))
        } else {
          setQueue(prev => prev.map(q => 
            q.id === itemId ? { ...q, progress: Math.round(progress) } : q
          ))
        }
      }, 500)

    } catch (err) {
      setQueue(prev => prev.map(q => 
        q.id === itemId ? { 
          ...q, 
          status: 'error' as const, 
          error: err instanceof Error ? err.message : 'Download failed' 
        } : q
      ))
    }
  }

  const removeFromQueue = (itemId: string) => {
    setQueue(prev => prev.filter(q => q.id !== itemId))
  }

  const retryDownload = (itemId: string) => {
    setQueue(prev => prev.map(q => 
      q.id === itemId ? { ...q, status: 'pending' as const, error: undefined } : q
    ))
    startDownload(itemId)
  }

  const clearCompleted = () => {
    setQueue(prev => prev.filter(q => q.status !== 'completed'))
  }

  const getStatusIcon = (status: DownloadItem['status']) => {
    switch (status) {
      case 'pending':
        return <Clock className="w-4 h-4 text-yellow-500" />
      case 'downloading':
        return <Download className="w-4 h-4 text-blue-500 animate-pulse" />
      case 'completed':
        return <CheckCircle className="w-4 h-4 text-green-500" />
      case 'error':
        return <XCircle className="w-4 h-4 text-red-500" />
    }
  }

  const formatFileSize = (bytes?: number): string => {
    if (!bytes) return 'Unknown size'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  return (
    <div className="bg-black rounded-lg border border-red-600 p-6">
      <div className="flex items-center gap-3 mb-6">
        <Youtube className="w-8 h-8 text-red-500" />
        <h2 className="text-2xl font-bold text-white">YouTube Downloader</h2>
      </div>

      {error && (
        <div className="bg-red-900 border border-red-600 text-white p-3 rounded-lg mb-4">
          {error}
        </div>
      )}

      {/* URL Input Section */}
      <div className="bg-gray-900 rounded-lg p-4 mb-6">
        <label className="block text-white text-sm font-medium mb-2">
          YouTube URL
        </label>
        <div className="flex gap-3">
          <input
            type="url"
            value={url}
            onChange={(e) => handleUrlChange(e.target.value)}
            placeholder="https://www.youtube.com/watch?v=..."
            className="flex-1 bg-gray-800 border border-gray-600 text-white px-3 py-2 rounded-lg focus:outline-none focus:border-red-500"
          />
          <button
            onClick={addToQueue}
            disabled={!url || !isValidYouTubeUrl(url) || downloading}
            className="bg-red-600 hover:bg-red-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white px-6 py-2 rounded-lg transition-colors flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Add to Queue
          </button>
        </div>

        {/* Quality Selector */}
        <div className="mt-4">
          <label className="block text-white text-sm font-medium mb-2">
            Quality
          </label>
          <select
            value={quality}
            onChange={(e) => setQuality(e.target.value)}
            className="bg-gray-800 border border-gray-600 text-white px-3 py-2 rounded-lg focus:outline-none focus:border-red-500"
          >
            {qualities.map(q => (
              <option key={q.value} value={q.value}>
                {q.label} - {q.description}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Video Info Preview */}
      {loadingInfo && (
        <div className="bg-gray-900 rounded-lg p-4 mb-6">
          <div className="text-white">Loading video information...</div>
        </div>
      )}

      {videoInfo && (
        <div className="bg-gray-900 rounded-lg p-4 mb-6">
          <div className="flex gap-4">
            <img
              src={videoInfo.thumbnail}
              alt={videoInfo.title}
              className="w-32 h-24 object-cover rounded-lg"
            />
            <div className="flex-1">
              <h3 className="text-white font-medium mb-2 line-clamp-2">
                {videoInfo.title}
              </h3>
              <p className="text-gray-400 text-sm mb-2">
                Duration: {videoInfo.duration}
              </p>
              <div className="text-gray-400 text-sm">
                Available formats: {videoInfo.formats.length}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Download Queue */}
      <div className="bg-gray-900 rounded-lg p-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-white font-medium">Download Queue ({queue.length})</h3>
          {queue.some(q => q.status === 'completed') && (
            <button
              onClick={clearCompleted}
              className="text-gray-400 hover:text-white text-sm transition-colors"
            >
              Clear Completed
            </button>
          )}
        </div>

        {queue.length === 0 ? (
          <div className="text-center py-8">
            <Download className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No downloads in queue</p>
            <p className="text-gray-500 text-sm mt-1">Add a YouTube URL to get started</p>
          </div>
        ) : (
          <div className="space-y-3">
            {queue.map((item) => (
              <div
                key={item.id}
                className="bg-gray-800 rounded-lg p-3 border border-gray-700"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-3">
                    {getStatusIcon(item.status)}
                    <div className="flex-1 min-w-0">
                      <p className="text-white font-medium truncate">
                        {item.title}
                      </p>
                      <p className="text-gray-400 text-sm">
                        Quality: {item.quality} • Added: {new Date(item.addedAt).toLocaleTimeString()}
                      </p>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-2">
                    {item.status === 'error' && (
                      <button
                        onClick={() => retryDownload(item.id)}
                        className="text-yellow-500 hover:text-yellow-400 transition-colors"
                        title="Retry download"
                      >
                        <Play className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => removeFromQueue(item.id)}
                      className="text-red-500 hover:text-red-400 transition-colors"
                      title="Remove from queue"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                {/* Progress Bar */}
                {item.status === 'downloading' && (
                  <div className="mb-2">
                    <div className="flex items-center justify-between text-sm text-gray-400 mb-1">
                      <span>Downloading...</span>
                      <span>{item.progress}%</span>
                    </div>
                    <div className="w-full bg-gray-700 rounded-full h-2">
                      <div 
                        className="bg-red-600 h-2 rounded-full transition-all duration-300"
                        style={{ width: `${item.progress}%` }}
                      />
                    </div>
                  </div>
                )}

                {/* Error Message */}
                {item.status === 'error' && item.error && (
                  <div className="text-red-400 text-sm mt-2">
                    Error: {item.error}
                  </div>
                )}

                {/* Success Message */}
                {item.status === 'completed' && (
                  <div className="text-green-400 text-sm mt-2">
                    ✓ Download completed successfully
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}