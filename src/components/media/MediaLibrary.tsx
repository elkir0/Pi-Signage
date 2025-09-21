'use client'

import React, { useState, useEffect, useCallback } from 'react'
import { Upload, Trash2, Image, Film, Music, FileText, Download } from 'lucide-react'

interface MediaFile {
  id: string
  name: string
  type: 'video' | 'image' | 'audio' | 'unknown'
  size: number
  createdAt: string
  modifiedAt: string
  thumbnail: string
  path: string
}

interface MediaLibraryProps {
  onMediaSelect?: (media: MediaFile) => void
  onMediaDelete?: (mediaId: string) => void
  selectedMedia?: string[]
}

export default function MediaLibrary({ 
  onMediaSelect, 
  onMediaDelete, 
  selectedMedia = [] 
}: MediaLibraryProps) {
  const [media, setMedia] = useState<MediaFile[]>([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [dragOver, setDragOver] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchMedia = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await fetch('/api/media')
      if (!response.ok) {
        throw new Error('Failed to fetch media')
      }
      const data = await response.json()
      setMedia(data.media || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load media')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchMedia()
  }, [fetchMedia])

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  const getMediaIcon = (type: string) => {
    switch (type) {
      case 'video':
        return <Film className="w-6 h-6 text-red-500" />
      case 'image':
        return <Image className="w-6 h-6 text-red-500" />
      case 'audio':
        return <Music className="w-6 h-6 text-red-500" />
      default:
        return <FileText className="w-6 h-6 text-red-500" />
    }
  }

  const handleFileUpload = async (files: FileList) => {
    if (files.length === 0) return

    setUploading(true)
    setUploadProgress(0)
    setError(null)

    try {
      for (let i = 0; i < files.length; i++) {
        const file = files[i]
        const formData = new FormData()
        formData.append('file', file)

        const xhr = new XMLHttpRequest()
        
        xhr.upload.addEventListener('progress', (event) => {
          if (event.lengthComputable) {
            const progress = ((i / files.length) + (event.loaded / event.total) / files.length) * 100
            setUploadProgress(Math.round(progress))
          }
        })

        await new Promise((resolve, reject) => {
          xhr.onload = () => {
            if (xhr.status === 200) {
              resolve(xhr.response)
            } else {
              reject(new Error(`Upload failed: ${xhr.statusText}`))
            }
          }
          xhr.onerror = () => reject(new Error('Upload failed'))
          xhr.open('POST', '/api/upload')
          xhr.send(formData)
        })
      }

      await fetchMedia()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed')
    } finally {
      setUploading(false)
      setUploadProgress(0)
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    setDragOver(true)
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    setDragOver(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setDragOver(false)
    const files = e.dataTransfer.files
    if (files.length > 0) {
      handleFileUpload(files)
    }
  }

  const handleDelete = async (mediaId: string) => {
    if (!confirm('Are you sure you want to delete this media file?')) return

    try {
      const response = await fetch(`/api/media?file=${encodeURIComponent(mediaId)}`, {
        method: 'DELETE'
      })
      
      if (!response.ok) {
        throw new Error('Failed to delete media')
      }

      setMedia(prev => prev.filter(m => m.id !== mediaId))
      onMediaDelete?.(mediaId)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete media')
    }
  }

  const handleMediaClick = (mediaFile: MediaFile) => {
    onMediaSelect?.(mediaFile)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 bg-black rounded-lg border border-red-600">
        <div className="text-white">Loading media library...</div>
      </div>
    )
  }

  return (
    <div className="bg-black rounded-lg border border-red-600 p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-white flex items-center gap-2">
          <Film className="w-6 h-6 text-red-500" />
          Media Library ({media.length} files)
        </h2>
        
        <label className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg cursor-pointer transition-colors flex items-center gap-2">
          <Upload className="w-4 h-4" />
          Upload Files
          <input
            type="file"
            multiple
            accept="video/*,image/*,audio/*"
            className="hidden"
            onChange={(e) => e.target.files && handleFileUpload(e.target.files)}
          />
        </label>
      </div>

      {error && (
        <div className="bg-red-900 border border-red-600 text-white p-3 rounded-lg mb-4">
          {error}
        </div>
      )}

      {/* Upload Progress */}
      {uploading && (
        <div className="mb-4">
          <div className="flex items-center justify-between text-white mb-2">
            <span>Uploading...</span>
            <span>{uploadProgress}%</span>
          </div>
          <div className="w-full bg-gray-700 rounded-full h-2">
            <div 
              className="bg-red-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${uploadProgress}%` }}
            />
          </div>
        </div>
      )}

      {/* Drag & Drop Zone */}
      <div
        className={`border-2 border-dashed rounded-lg p-8 mb-6 transition-colors ${
          dragOver 
            ? 'border-red-500 bg-red-900/20' 
            : 'border-gray-600 hover:border-red-500'
        }`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        <div className="text-center">
          <Download className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-300 mb-2">Drag & drop files here, or click to select</p>
          <p className="text-sm text-gray-500">Supports: MP4, AVI, MKV, JPG, PNG, MP3, WAV</p>
        </div>
      </div>

      {/* Media Grid */}
      {media.length === 0 ? (
        <div className="text-center py-12">
          <Image className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <p className="text-gray-400">No media files found</p>
          <p className="text-sm text-gray-500 mt-2">Upload some files to get started</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {media.map((mediaFile) => (
            <div
              key={mediaFile.id}
              className={`bg-gray-900 rounded-lg border transition-all cursor-pointer hover:bg-gray-800 ${
                selectedMedia.includes(mediaFile.id)
                  ? 'border-red-500 ring-2 ring-red-500/50'
                  : 'border-gray-700 hover:border-red-500'
              }`}
              onClick={() => handleMediaClick(mediaFile)}
            >
              {/* Thumbnail */}
              <div className="aspect-video bg-gray-800 rounded-t-lg overflow-hidden relative">
                {mediaFile.type === 'image' ? (
                  <img
                    src={mediaFile.path}
                    alt={mediaFile.name}
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      const target = e.target as HTMLImageElement
                      target.style.display = 'none'
                      target.nextElementSibling?.classList.remove('hidden')
                    }}
                  />
                ) : (
                  <img
                    src={mediaFile.thumbnail}
                    alt={mediaFile.name}
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      const target = e.target as HTMLImageElement
                      target.style.display = 'none'
                      target.nextElementSibling?.classList.remove('hidden')
                    }}
                  />
                )}
                <div className="hidden absolute inset-0 flex items-center justify-center">
                  {getMediaIcon(mediaFile.type)}
                </div>
                
                {/* Type indicator */}
                <div className="absolute top-2 left-2 bg-black/80 rounded px-2 py-1 text-xs text-white">
                  {mediaFile.type.toUpperCase()}
                </div>
              </div>

              {/* Info */}
              <div className="p-3">
                <h3 className="text-white font-medium truncate mb-1">
                  {mediaFile.name}
                </h3>
                <p className="text-gray-400 text-sm">
                  {formatFileSize(mediaFile.size)}
                </p>
                <p className="text-gray-500 text-xs mt-1">
                  {new Date(mediaFile.createdAt).toLocaleDateString()}
                </p>
              </div>

              {/* Actions */}
              <div className="px-3 pb-3">
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    handleDelete(mediaFile.id)
                  }}
                  className="w-full bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm transition-colors flex items-center justify-center gap-2"
                >
                  <Trash2 className="w-3 h-3" />
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}