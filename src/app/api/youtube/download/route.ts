import { NextRequest, NextResponse } from 'next/server'
import { exec, spawn } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'
import path from 'path'

const execAsync = promisify(exec)

interface DownloadProgress {
  id: string
  url: string
  status: 'pending' | 'downloading' | 'completed' | 'error'
  progress: number
  filename?: string
  error?: string
  startTime: string
  endTime?: string
  size?: string
  speed?: string
}

interface DownloadRequest {
  url: string
  quality?: string
  format?: string
  audioOnly?: boolean
}

interface DownloadResponse {
  success: boolean
  data?: {
    downloadId: string
    status: string
    message: string
  }
  error?: string
}

const MEDIA_DIR = '/opt/pisignage/media'
const PROGRESS_DIR = '/opt/pisignage/src/data/download-progress'
const MAX_CONCURRENT_DOWNLOADS = 3

function isValidYouTubeUrl(url: string): boolean {
  const youtubeRegex = /^(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/|m\.youtube\.com\/watch\?v=)([a-zA-Z0-9_-]{11})/
  return youtubeRegex.test(url)
}

function extractVideoId(url: string): string | null {
  const regex = /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/|m\.youtube\.com\/watch\?v=)([a-zA-Z0-9_-]{11})/
  const match = url.match(regex)
  return match ? match[1] : null
}

function sanitizeShellArg(arg: string): string {
  return arg.replace(/[;&|`$(){}[\]<>]/g, '').replace(/"/g, '\\"')
}

function generateDownloadId(): string {
  return `dl_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

async function ensureDirectories() {
  await fs.mkdir(MEDIA_DIR, { recursive: true })
  await fs.mkdir(PROGRESS_DIR, { recursive: true })
}

async function saveProgress(progress: DownloadProgress) {
  const progressFile = path.join(PROGRESS_DIR, `${progress.id}.json`)
  await fs.writeFile(progressFile, JSON.stringify(progress, null, 2))
}

async function loadProgress(downloadId: string): Promise<DownloadProgress | null> {
  try {
    const progressFile = path.join(PROGRESS_DIR, `${downloadId}.json`)
    const data = await fs.readFile(progressFile, 'utf-8')
    return JSON.parse(data)
  } catch {
    return null
  }
}

async function getAllProgress(): Promise<DownloadProgress[]> {
  try {
    const files = await fs.readdir(PROGRESS_DIR)
    const progressFiles = files.filter(f => f.endsWith('.json'))
    
    const progressList = await Promise.all(
      progressFiles.map(async (file) => {
        try {
          const data = await fs.readFile(path.join(PROGRESS_DIR, file), 'utf-8')
          return JSON.parse(data)
        } catch {
          return null
        }
      })
    )
    
    return progressList.filter(p => p !== null)
  } catch {
    return []
  }
}

async function countActiveDownloads(): Promise<number> {
  const allProgress = await getAllProgress()
  return allProgress.filter(p => p.status === 'downloading').length
}

function startDownload(downloadId: string, url: string, options: {
  quality?: string
  format?: string
  audioOnly?: boolean
}) {
  const { quality = 'best', format = 'mp4', audioOnly = false } = options
  
  const sanitizedUrl = sanitizeShellArg(url)
  const outputTemplate = path.join(MEDIA_DIR, '%(title)s.%(ext)s')
  
  let ytDlpArgs = [
    '--no-playlist',
    '--output', outputTemplate,
    '--newline'
  ]
  
  if (audioOnly) {
    ytDlpArgs.push('--extract-audio', '--audio-format', 'mp3')
  } else {
    if (quality === 'best') {
      ytDlpArgs.push('--format', 'best[ext=mp4]/best')
    } else if (quality === 'worst') {
      ytDlpArgs.push('--format', 'worst[ext=mp4]/worst')
    } else {
      ytDlpArgs.push('--format', `best[height<=${quality}][ext=mp4]/best[height<=${quality}]/best`)
    }
  }
  
  ytDlpArgs.push(sanitizedUrl)
  
  const child = spawn('yt-dlp', ytDlpArgs, {
    stdio: ['ignore', 'pipe', 'pipe']
  })
  
  let currentFilename = ''
  
  child.stdout?.on('data', async (data) => {
    const output = data.toString()
    const lines = output.split('\n')
    
    for (const line of lines) {
      if (line.includes('[download]') && line.includes('%')) {
        // Parse download progress
        const progressMatch = line.match(/(\d+\.?\d*)%/)
        const speedMatch = line.match(/(\d+\.?\d*\w+\/s)/)
        const sizeMatch = line.match(/(\d+\.?\d*\w+)/)
        
        if (progressMatch) {
          const progress = parseFloat(progressMatch[1])
          const speed = speedMatch ? speedMatch[1] : undefined
          const size = sizeMatch ? sizeMatch[1] : undefined
          
          const progressData = await loadProgress(downloadId)
          if (progressData) {
            progressData.progress = progress
            progressData.speed = speed
            progressData.size = size
            await saveProgress(progressData)
          }
        }
      } else if (line.includes('[download] Destination:')) {
        // Extract filename
        const filenameMatch = line.match(/\[download\] Destination: (.+)/)
        if (filenameMatch) {
          currentFilename = path.basename(filenameMatch[1])
        }
      }
    }
  })
  
  child.stderr?.on('data', async (data) => {
    const error = data.toString()
    console.error(`Download ${downloadId} error:`, error)
    
    const progressData = await loadProgress(downloadId)
    if (progressData) {
      progressData.status = 'error'
      progressData.error = error
      progressData.endTime = new Date().toISOString()
      await saveProgress(progressData)
    }
  })
  
  child.on('close', async (code) => {
    const progressData = await loadProgress(downloadId)
    if (progressData) {
      if (code === 0) {
        progressData.status = 'completed'
        progressData.progress = 100
        progressData.filename = currentFilename
      } else {
        progressData.status = 'error'
        progressData.error = `Download failed with exit code ${code}`
      }
      progressData.endTime = new Date().toISOString()
      await saveProgress(progressData)
    }
  })
  
  return child
}

export async function POST(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const body: DownloadRequest = await request.json()
    const { url, quality = 'best', format = 'mp4', audioOnly = false } = body
    
    if (!url) {
      return NextResponse.json(
        { success: false, error: 'YouTube URL is required' },
        { status: 400 }
      )
    }
    
    if (!isValidYouTubeUrl(url)) {
      return NextResponse.json(
        { success: false, error: 'Invalid YouTube URL format' },
        { status: 400 }
      )
    }
    
    // Check if we've reached the maximum concurrent downloads
    const activeDownloads = await countActiveDownloads()
    if (activeDownloads >= MAX_CONCURRENT_DOWNLOADS) {
      return NextResponse.json(
        { success: false, error: `Maximum ${MAX_CONCURRENT_DOWNLOADS} concurrent downloads allowed` },
        { status: 429 }
      )
    }
    
    // Check if yt-dlp is available
    try {
      await execAsync('which yt-dlp')
    } catch {
      return NextResponse.json(
        { success: false, error: 'yt-dlp is not installed on the system' },
        { status: 500 }
      )
    }
    
    const downloadId = generateDownloadId()
    const videoId = extractVideoId(url)
    
    // Initialize progress tracking
    const progressData: DownloadProgress = {
      id: downloadId,
      url,
      status: 'pending',
      progress: 0,
      startTime: new Date().toISOString()
    }
    
    await saveProgress(progressData)
    
    // Start download in background
    progressData.status = 'downloading'
    await saveProgress(progressData)
    
    startDownload(downloadId, url, { quality, format, audioOnly })
    
    return NextResponse.json({
      success: true,
      data: {
        downloadId,
        status: 'downloading',
        message: 'Download started successfully'
      }
    })
    
  } catch (error) {
    console.error('YouTube download API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to start download' 
      },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const searchParams = request.nextUrl.searchParams
    const downloadId = searchParams.get('id')
    
    if (downloadId) {
      // Get specific download progress
      const progress = await loadProgress(downloadId)
      if (!progress) {
        return NextResponse.json(
          { success: false, error: 'Download not found' },
          { status: 404 }
        )
      }
      
      return NextResponse.json({
        success: true,
        data: progress
      })
    } else {
      // Get all downloads
      const allProgress = await getAllProgress()
      
      return NextResponse.json({
        success: true,
        data: allProgress.sort((a, b) => 
          new Date(b.startTime).getTime() - new Date(a.startTime).getTime()
        )
      })
    }
    
  } catch (error) {
    console.error('YouTube download status API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to get download status' 
      },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const downloadId = searchParams.get('id')
    
    if (!downloadId) {
      return NextResponse.json(
        { success: false, error: 'Download ID is required' },
        { status: 400 }
      )
    }
    
    // Remove progress file
    const progressFile = path.join(PROGRESS_DIR, `${downloadId}.json`)
    try {
      await fs.unlink(progressFile)
    } catch {
      // File might not exist
    }
    
    return NextResponse.json({
      success: true,
      message: 'Download record deleted'
    })
    
  } catch (error) {
    console.error('YouTube download delete API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to delete download record' 
      },
      { status: 500 }
    )
  }
}