'use client'

import React, { useState, useEffect, useCallback } from 'react'
import { Camera, RefreshCw, Download, Clock, Monitor } from 'lucide-react'

interface ScreenshotData {
  url: string
  timestamp: string
  size?: number
}

export default function Screenshot() {
  const [screenshot, setScreenshot] = useState<ScreenshotData | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [autoRefresh, setAutoRefresh] = useState(false)
  const [refreshInterval, setRefreshInterval] = useState(30)

  const takeScreenshot = useCallback(async () => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch('/api/system/screenshot', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      })

      if (!response.ok) {
        throw new Error('Failed to take screenshot')
      }

      const data = await response.json()
      
      setScreenshot({
        url: data.url,
        timestamp: new Date().toISOString(),
        size: data.size
      })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to take screenshot')
    } finally {
      setLoading(false)
    }
  }, [])

  // Auto-refresh functionality
  useEffect(() => {
    let intervalId: NodeJS.Timeout

    if (autoRefresh && refreshInterval > 0) {
      intervalId = setInterval(() => {
        takeScreenshot()
      }, refreshInterval * 1000)
    }

    return () => {
      if (intervalId) {
        clearInterval(intervalId)
      }
    }
  }, [autoRefresh, refreshInterval, takeScreenshot])

  // Take initial screenshot on mount
  useEffect(() => {
    takeScreenshot()
  }, [takeScreenshot])

  const formatFileSize = (bytes?: number): string => {
    if (!bytes) return 'Unknown size'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  const formatTimestamp = (timestamp: string): string => {
    return new Date(timestamp).toLocaleString()
  }

  const downloadScreenshot = () => {
    if (!screenshot) return

    const link = document.createElement('a')
    link.href = screenshot.url
    link.download = `screenshot-${new Date(screenshot.timestamp).toISOString().replace(/[:.]/g, '-')}.png`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  const getTimeSinceLastUpdate = (): string => {
    if (!screenshot) return ''
    
    const now = new Date()
    const screenshotTime = new Date(screenshot.timestamp)
    const diffInSeconds = Math.floor((now.getTime() - screenshotTime.getTime()) / 1000)
    
    if (diffInSeconds < 60) {
      return `${diffInSeconds} seconds ago`
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60)
      return `${minutes} minute${minutes !== 1 ? 's' : ''} ago`
    } else {
      const hours = Math.floor(diffInSeconds / 3600)
      return `${hours} hour${hours !== 1 ? 's' : ''} ago`
    }
  }

  return (
    <div className="bg-black rounded-lg border border-red-600 p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <Monitor className="w-8 h-8 text-red-500" />
          <div>
            <h2 className="text-2xl font-bold text-white">Screen Capture</h2>
            <p className="text-gray-400 text-sm">Real-time display monitoring</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* Auto-refresh toggle */}
          <div className="flex items-center gap-2">
            <label className="flex items-center gap-2 text-white text-sm cursor-pointer">
              <input
                type="checkbox"
                checked={autoRefresh}
                onChange={(e) => setAutoRefresh(e.target.checked)}
                className="w-4 h-4 text-red-600 bg-gray-800 border-gray-600 rounded focus:ring-red-500 focus:ring-2"
              />
              Auto-refresh
            </label>
            
            {autoRefresh && (
              <select
                value={refreshInterval}
                onChange={(e) => setRefreshInterval(Number(e.target.value))}
                className="bg-gray-800 border border-gray-600 text-white px-2 py-1 rounded text-sm focus:outline-none focus:border-red-500"
              >
                <option value={5}>5s</option>
                <option value={10}>10s</option>
                <option value={30}>30s</option>
                <option value={60}>1m</option>
                <option value={300}>5m</option>
              </select>
            )}
          </div>

          {/* Manual refresh button */}
          <button
            onClick={takeScreenshot}
            disabled={loading}
            className="bg-red-600 hover:bg-red-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white px-4 py-2 rounded-lg transition-colors flex items-center gap-2"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            {loading ? 'Capturing...' : 'Refresh'}
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-900 border border-red-600 text-white p-3 rounded-lg mb-4">
          <div className="flex items-center gap-2">
            <Camera className="w-5 h-5" />
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Screenshot Status */}
      {screenshot && (
        <div className="bg-gray-900 rounded-lg p-4 mb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 text-green-400">
                <Camera className="w-4 h-4" />
                <span className="text-sm font-medium">Last captured</span>
              </div>
              <div className="text-white text-sm">
                {formatTimestamp(screenshot.timestamp)}
              </div>
              <div className="text-gray-400 text-sm">
                ({getTimeSinceLastUpdate()})
              </div>
            </div>
            
            <div className="flex items-center gap-3">
              {screenshot.size && (
                <span className="text-gray-400 text-sm">
                  {formatFileSize(screenshot.size)}
                </span>
              )}
              <button
                onClick={downloadScreenshot}
                className="bg-gray-700 hover:bg-gray-600 text-white px-3 py-1 rounded text-sm transition-colors flex items-center gap-2"
              >
                <Download className="w-3 h-3" />
                Download
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Screenshot Display */}
      <div className="bg-gray-900 rounded-lg p-4">
        {loading && !screenshot && (
          <div className="aspect-video bg-gray-800 rounded-lg flex items-center justify-center">
            <div className="text-center">
              <Camera className="w-12 h-12 text-gray-600 mx-auto mb-3 animate-pulse" />
              <p className="text-gray-400">Taking screenshot...</p>
            </div>
          </div>
        )}

        {screenshot && (
          <div className="relative">
            <img
              src={screenshot.url}
              alt="Current screen capture"
              className="w-full h-auto rounded-lg border border-gray-700"
              onError={(e) => {
                setError('Failed to load screenshot image')
                setScreenshot(null)
              }}
            />
            
            {loading && (
              <div className="absolute inset-0 bg-black/50 rounded-lg flex items-center justify-center">
                <div className="bg-gray-800 rounded-lg p-3 flex items-center gap-2">
                  <RefreshCw className="w-4 h-4 text-white animate-spin" />
                  <span className="text-white text-sm">Updating...</span>
                </div>
              </div>
            )}

            {/* Screenshot overlay info */}
            <div className="absolute top-3 left-3 bg-black/80 rounded px-2 py-1 text-xs text-white">
              Live Display
            </div>
            
            {autoRefresh && (
              <div className="absolute top-3 right-3 bg-black/80 rounded px-2 py-1 text-xs text-white flex items-center gap-1">
                <Clock className="w-3 h-3" />
                Auto-refresh: {refreshInterval}s
              </div>
            )}
          </div>
        )}

        {!screenshot && !loading && (
          <div className="aspect-video bg-gray-800 rounded-lg flex items-center justify-center">
            <div className="text-center">
              <Monitor className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <p className="text-gray-400 mb-2">No screenshot available</p>
              <p className="text-gray-500 text-sm">Click "Refresh" to capture the current display</p>
            </div>
          </div>
        )}
      </div>

      {/* Instructions */}
      <div className="mt-4 p-3 bg-gray-900 rounded-lg border border-gray-700">
        <h3 className="text-white font-medium mb-2 flex items-center gap-2">
          <Camera className="w-4 h-4 text-red-500" />
          Screenshot Info
        </h3>
        <div className="text-gray-400 text-sm space-y-1">
          <p>• Captures the current display output from the Pi-Signage system</p>
          <p>• Auto-refresh can be enabled for continuous monitoring</p>
          <p>• Screenshots can be downloaded for troubleshooting or documentation</p>
          <p>• Useful for verifying playlist playback and content display</p>
        </div>
      </div>
    </div>
  )
}