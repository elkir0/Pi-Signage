import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

interface VolumeInfo {
  level: number
  muted: boolean
  device: string
}

interface VolumeResponse {
  success: boolean
  data?: VolumeInfo | { message: string }
  error?: string
}

async function getCurrentVolume(): Promise<VolumeInfo> {
  try {
    // Get volume level using amixer
    const { stdout } = await execAsync("amixer get PCM | grep -E 'Mono:|Left:'")
    
    // Parse the output to extract volume percentage
    const volumeMatch = stdout.match(/\[(\d+)%\]/)
    const muteMatch = stdout.match(/\[(on|off)\]/)
    
    const level = volumeMatch ? parseInt(volumeMatch[1]) : 0
    const muted = muteMatch ? muteMatch[1] === 'off' : false
    
    return {
      level,
      muted,
      device: 'PCM'
    }
  } catch (error) {
    // Fallback: try with Master control
    try {
      const { stdout } = await execAsync("amixer get Master | grep -E 'Mono:|Left:'")
      
      const volumeMatch = stdout.match(/\[(\d+)%\]/)
      const muteMatch = stdout.match(/\[(on|off)\]/)
      
      const level = volumeMatch ? parseInt(volumeMatch[1]) : 0
      const muted = muteMatch ? muteMatch[1] === 'off' : false
      
      return {
        level,
        muted,
        device: 'Master'
      }
    } catch (fallbackError) {
      throw new Error('Failed to get volume information from amixer')
    }
  }
}

async function setVolume(level: number, device: string = 'PCM'): Promise<void> {
  // Validate volume level
  if (level < 0 || level > 100) {
    throw new Error('Volume level must be between 0 and 100')
  }
  
  try {
    // Set volume using amixer
    await execAsync(`amixer set ${device} ${level}%`)
  } catch (error) {
    // Fallback: try with Master if PCM fails
    if (device === 'PCM') {
      try {
        await execAsync(`amixer set Master ${level}%`)
      } catch (fallbackError) {
        throw new Error('Failed to set volume using amixer')
      }
    } else {
      throw new Error('Failed to set volume using amixer')
    }
  }
}

async function muteVolume(device: string = 'PCM'): Promise<void> {
  try {
    await execAsync(`amixer set ${device} mute`)
  } catch (error) {
    // Fallback: try with Master if PCM fails
    if (device === 'PCM') {
      try {
        await execAsync(`amixer set Master mute`)
      } catch (fallbackError) {
        throw new Error('Failed to mute volume using amixer')
      }
    } else {
      throw new Error('Failed to mute volume using amixer')
    }
  }
}

async function unmuteVolume(device: string = 'PCM'): Promise<void> {
  try {
    await execAsync(`amixer set ${device} unmute`)
  } catch (error) {
    // Fallback: try with Master if PCM fails
    if (device === 'PCM') {
      try {
        await execAsync(`amixer set Master unmute`)
      } catch (fallbackError) {
        throw new Error('Failed to unmute volume using amixer')
      }
    } else {
      throw new Error('Failed to unmute volume using amixer')
    }
  }
}

async function increaseVolume(step: number = 5, device: string = 'PCM'): Promise<void> {
  if (step <= 0 || step > 20) {
    throw new Error('Volume step must be between 1 and 20')
  }
  
  try {
    await execAsync(`amixer set ${device} ${step}%+`)
  } catch (error) {
    // Fallback: try with Master if PCM fails
    if (device === 'PCM') {
      try {
        await execAsync(`amixer set Master ${step}%+`)
      } catch (fallbackError) {
        throw new Error('Failed to increase volume using amixer')
      }
    } else {
      throw new Error('Failed to increase volume using amixer')
    }
  }
}

async function decreaseVolume(step: number = 5, device: string = 'PCM'): Promise<void> {
  if (step <= 0 || step > 20) {
    throw new Error('Volume step must be between 1 and 20')
  }
  
  try {
    await execAsync(`amixer set ${device} ${step}%-`)
  } catch (error) {
    // Fallback: try with Master if PCM fails
    if (device === 'PCM') {
      try {
        await execAsync(`amixer set Master ${step}%-`)
      } catch (fallbackError) {
        throw new Error('Failed to decrease volume using amixer')
      }
    } else {
      throw new Error('Failed to decrease volume using amixer')
    }
  }
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const action = searchParams.get('action')
    
    switch (action) {
      case 'status':
      case null:
      case undefined:
        const volumeInfo = await getCurrentVolume()
        return NextResponse.json({
          success: true,
          data: volumeInfo
        })
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Volume GET API error:', error)
    
    // Check if amixer is available
    try {
      await execAsync('which amixer')
    } catch {
      return NextResponse.json(
        { success: false, error: 'amixer is not installed on the system' },
        { status: 500 }
      )
    }
    
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to get volume information' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, level, step, device } = body
    
    if (!action) {
      return NextResponse.json(
        { success: false, error: 'Action is required' },
        { status: 400 }
      )
    }
    
    const volumeDevice = device || 'PCM'
    
    switch (action) {
      case 'set':
        if (typeof level !== 'number') {
          return NextResponse.json(
            { success: false, error: 'Level is required for set action' },
            { status: 400 }
          )
        }
        
        await setVolume(level, volumeDevice)
        const newVolumeInfo = await getCurrentVolume()
        
        return NextResponse.json({
          success: true,
          data: {
            message: `Volume set to ${level}%`,
            ...newVolumeInfo
          }
        })
      
      case 'mute':
        await muteVolume(volumeDevice)
        return NextResponse.json({
          success: true,
          data: { message: 'Volume muted' }
        })
      
      case 'unmute':
        await unmuteVolume(volumeDevice)
        return NextResponse.json({
          success: true,
          data: { message: 'Volume unmuted' }
        })
      
      case 'toggle':
        const currentVolume = await getCurrentVolume()
        if (currentVolume.muted) {
          await unmuteVolume(volumeDevice)
          return NextResponse.json({
            success: true,
            data: { message: 'Volume unmuted' }
          })
        } else {
          await muteVolume(volumeDevice)
          return NextResponse.json({
            success: true,
            data: { message: 'Volume muted' }
          })
        }
      
      case 'increase':
        const increaseStep = typeof step === 'number' ? step : 5
        await increaseVolume(increaseStep, volumeDevice)
        const increasedVolume = await getCurrentVolume()
        
        return NextResponse.json({
          success: true,
          data: {
            message: `Volume increased by ${increaseStep}%`,
            ...increasedVolume
          }
        })
      
      case 'decrease':
        const decreaseStep = typeof step === 'number' ? step : 5
        await decreaseVolume(decreaseStep, volumeDevice)
        const decreasedVolume = await getCurrentVolume()
        
        return NextResponse.json({
          success: true,
          data: {
            message: `Volume decreased by ${decreaseStep}%`,
            ...decreasedVolume
          }
        })
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Volume POST API error:', error)
    
    // Check if amixer is available
    try {
      await execAsync('which amixer')
    } catch {
      return NextResponse.json(
        { success: false, error: 'amixer is not installed on the system' },
        { status: 500 }
      )
    }
    
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Volume operation failed' 
      },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { level, device } = body
    
    if (typeof level !== 'number') {
      return NextResponse.json(
        { success: false, error: 'Level is required' },
        { status: 400 }
      )
    }
    
    const volumeDevice = device || 'PCM'
    await setVolume(level, volumeDevice)
    const newVolumeInfo = await getCurrentVolume()
    
    return NextResponse.json({
      success: true,
      data: {
        message: `Volume set to ${level}%`,
        ...newVolumeInfo
      }
    })
    
  } catch (error) {
    console.error('Volume PUT API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to set volume' 
      },
      { status: 500 }
    )
  }
}

export async function PATCH(request: NextRequest) {
  // Alias for POST to support partial updates
  return POST(request)
}