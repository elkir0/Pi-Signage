import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'
import path from 'path'

const execAsync = promisify(exec)

interface VLCStatus {
  isRunning: boolean
  pid?: number
  playlist?: string
  currentMedia?: string
  status?: 'playing' | 'paused' | 'stopped'
  position?: number
  length?: number
  volume?: number
}

interface VLCControlResponse {
  success: boolean
  data?: VLCStatus | { message: string }
  error?: string
}

const MEDIA_DIR = '/opt/pisignage/media'
const PLAYLIST_DIR = '/opt/pisignage/src/data/playlists'
const VLC_CONTROL_SCRIPT = '/opt/pisignage/src/scripts/player-control.sh'

function sanitizeShellArg(arg: string): string {
  // Remove dangerous characters and escape quotes
  return arg.replace(/[;&|`$(){}[\]<>]/g, '').replace(/"/g, '\\"')
}

async function getVLCStatus(): Promise<VLCStatus> {
  const status: VLCStatus = { isRunning: false }
  
  try {
    // Check if VLC process is running
    const { stdout } = await execAsync('pgrep -f vlc')
    const pids = stdout.trim().split('\n').filter(p => p.length > 0)
    
    if (pids.length > 0) {
      status.isRunning = true
      status.pid = parseInt(pids[0])
      
      // Try to get more detailed status if VLC HTTP interface is available
      try {
        const vlcStatus = await getVLCHttpStatus()
        Object.assign(status, vlcStatus)
      } catch {
        // HTTP interface not available, use basic status
        status.status = 'playing'
      }
    }
  } catch {
    // No VLC processes found
  }
  
  return status
}

async function getVLCHttpStatus(): Promise<Partial<VLCStatus>> {
  try {
    // Try to connect to VLC HTTP interface (usually on port 8080)
    const response = await fetch('http://localhost:8080/requests/status.json', {
      headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
    })
    
    if (response.ok) {
      const data = await response.json()
      return {
        status: data.state as 'playing' | 'paused' | 'stopped',
        position: data.time,
        length: data.length,
        volume: data.volume,
        currentMedia: data.information?.category?.meta?.filename
      }
    }
  } catch {
    // HTTP interface not available
  }
  
  return {}
}

async function startVLC(mediaPath?: string, playlistPath?: string): Promise<void> {
  try {
    // Stop any existing VLC instances first
    await stopVLC()
    
    let command = 'vlc'
    const args = [
      '--intf', 'http',
      '--http-password', 'vlc',
      '--http-port', '8080',
      '--fullscreen',
      '--no-video-title-show',
      '--loop'
    ]
    
    if (playlistPath && await fs.access(playlistPath).then(() => true).catch(() => false)) {
      args.push(playlistPath)
    } else if (mediaPath && await fs.access(mediaPath).then(() => true).catch(() => false)) {
      args.push(mediaPath)
    } else {
      // Default: play all media files in the media directory
      try {
        const files = await fs.readdir(MEDIA_DIR)
        const mediaFiles = files.filter(file => {
          const ext = path.extname(file).toLowerCase()
          return ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v'].includes(ext)
        })
        
        if (mediaFiles.length > 0) {
          // Add all media files to command
          mediaFiles.forEach(file => {
            args.push(path.join(MEDIA_DIR, file))
          })
        } else {
          throw new Error('No media files found in media directory')
        }
      } catch (error) {
        throw new Error('No media to play and no files in media directory')
      }
    }
    
    // Start VLC in background
    const fullCommand = `${command} ${args.map(arg => `"${sanitizeShellArg(arg)}"`).join(' ')} &`
    await execAsync(fullCommand, { timeout: 10000 })
    
    // Wait a moment for VLC to start
    await new Promise(resolve => setTimeout(resolve, 2000))
    
  } catch (error) {
    throw new Error(`Failed to start VLC: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

async function stopVLC(): Promise<void> {
  try {
    // Kill all VLC processes
    await execAsync('pkill -f vlc || true')
    
    // Wait a moment for processes to terminate
    await new Promise(resolve => setTimeout(resolve, 1000))
    
  } catch (error) {
    // Ignore errors when stopping (processes might not exist)
  }
}

async function pauseVLC(): Promise<void> {
  try {
    // Try HTTP interface first
    const response = await fetch('http://localhost:8080/requests/status.json?command=pl_pause', {
      method: 'GET',
      headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
    })
    
    if (!response.ok) {
      throw new Error('HTTP interface not available')
    }
  } catch {
    // Fallback: send SIGUSR1 signal to VLC process
    try {
      const { stdout } = await execAsync('pgrep -f vlc')
      const pids = stdout.trim().split('\n').filter(p => p.length > 0)
      
      if (pids.length > 0) {
        await execAsync(`kill -USR1 ${pids[0]}`)
      } else {
        throw new Error('VLC is not running')
      }
    } catch {
      throw new Error('Failed to pause VLC')
    }
  }
}

async function resumeVLC(): Promise<void> {
  try {
    // Try HTTP interface first
    const response = await fetch('http://localhost:8080/requests/status.json?command=pl_play', {
      method: 'GET',
      headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
    })
    
    if (!response.ok) {
      throw new Error('HTTP interface not available')
    }
  } catch {
    throw new Error('Failed to resume VLC - HTTP interface not available')
  }
}

async function nextTrack(): Promise<void> {
  try {
    const response = await fetch('http://localhost:8080/requests/status.json?command=pl_next', {
      method: 'GET',
      headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
    })
    
    if (!response.ok) {
      throw new Error('HTTP interface not available')
    }
  } catch {
    throw new Error('Failed to skip to next track')
  }
}

async function previousTrack(): Promise<void> {
  try {
    const response = await fetch('http://localhost:8080/requests/status.json?command=pl_previous', {
      method: 'GET',
      headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
    })
    
    if (!response.ok) {
      throw new Error('HTTP interface not available')
    }
  } catch {
    throw new Error('Failed to skip to previous track')
  }
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const action = searchParams.get('action')
    
    switch (action) {
      case 'status':
        const status = await getVLCStatus()
        return NextResponse.json({
          success: true,
          data: status
        })
      
      default:
        const defaultStatus = await getVLCStatus()
        return NextResponse.json({
          success: true,
          data: defaultStatus
        })
    }
    
  } catch (error) {
    console.error('VLC GET API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to get VLC status' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, mediaPath, playlistPath, volume } = body
    
    if (!action) {
      return NextResponse.json(
        { success: false, error: 'Action is required' },
        { status: 400 }
      )
    }
    
    switch (action) {
      case 'start':
      case 'play':
        await startVLC(mediaPath, playlistPath)
        return NextResponse.json({
          success: true,
          data: { message: 'VLC started successfully' }
        })
      
      case 'stop':
        await stopVLC()
        return NextResponse.json({
          success: true,
          data: { message: 'VLC stopped successfully' }
        })
      
      case 'pause':
        await pauseVLC()
        return NextResponse.json({
          success: true,
          data: { message: 'VLC paused successfully' }
        })
      
      case 'resume':
        await resumeVLC()
        return NextResponse.json({
          success: true,
          data: { message: 'VLC resumed successfully' }
        })
      
      case 'next':
        await nextTrack()
        return NextResponse.json({
          success: true,
          data: { message: 'Skipped to next track' }
        })
      
      case 'previous':
        await previousTrack()
        return NextResponse.json({
          success: true,
          data: { message: 'Skipped to previous track' }
        })
      
      case 'restart':
        await stopVLC()
        await new Promise(resolve => setTimeout(resolve, 2000))
        await startVLC(mediaPath, playlistPath)
        return NextResponse.json({
          success: true,
          data: { message: 'VLC restarted successfully' }
        })
      
      case 'volume':
        if (typeof volume !== 'number' || volume < 0 || volume > 100) {
          return NextResponse.json(
            { success: false, error: 'Volume must be a number between 0 and 100' },
            { status: 400 }
          )
        }
        
        try {
          // Set volume via HTTP interface
          const response = await fetch(`http://localhost:8080/requests/status.json?command=volume&val=${Math.round(volume * 2.56)}`, {
            method: 'GET',
            headers: { 'Authorization': 'Basic ' + Buffer.from(':vlc').toString('base64') }
          })
          
          if (!response.ok) {
            throw new Error('HTTP interface not available')
          }
          
          return NextResponse.json({
            success: true,
            data: { message: `Volume set to ${volume}%` }
          })
        } catch {
          return NextResponse.json(
            { success: false, error: 'Failed to set volume - VLC HTTP interface not available' },
            { status: 500 }
          )
        }
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('VLC POST API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'VLC operation failed' 
      },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  // Alias for POST to support different HTTP methods
  return POST(request)
}

export async function PATCH(request: NextRequest) {
  // Alias for POST to support different HTTP methods
  return POST(request)
}