import { NextRequest, NextResponse } from 'next/server'
import fs from 'fs/promises'
import path from 'path'

interface PiSignageSettings {
  display: {
    resolution?: string
    orientation?: 'landscape' | 'portrait'
    brightness?: number
    screensaver?: boolean
    screensaverTimeout?: number
  }
  player: {
    defaultVolume?: number
    autoplay?: boolean
    loop?: boolean
    shuffle?: boolean
    imageDisplayDuration?: number
    transitionEffect?: string
  }
  network: {
    wifi?: {
      enabled: boolean
      ssid?: string
      autoConnect?: boolean
    }
    hotspot?: {
      enabled: boolean
      ssid?: string
      password?: string
    }
  }
  system: {
    hostname?: string
    timezone?: string
    autoUpdate?: boolean
    logLevel?: 'debug' | 'info' | 'warn' | 'error'
    maxLogSize?: number
  }
  api: {
    enableCors?: boolean
    rateLimit?: number
    maxUploadSize?: number
    allowedOrigins?: string[]
  }
  playlist: {
    defaultPlaylist?: string
    autoCreateDefault?: boolean
    includeImages?: boolean
    includeVideos?: boolean
  }
  advanced: {
    vlcArguments?: string[]
    customCss?: string
    debugMode?: boolean
    experimentalFeatures?: boolean
  }
}

interface SettingsResponse {
  success: boolean
  data?: PiSignageSettings | { message: string }
  error?: string
}

const SETTINGS_FILE = '/opt/pisignage/src/data/settings.json'
const BACKUP_DIR = '/opt/pisignage/src/data/settings-backup'

// Default settings
const DEFAULT_SETTINGS: PiSignageSettings = {
  display: {
    resolution: 'auto',
    orientation: 'landscape',
    brightness: 80,
    screensaver: false,
    screensaverTimeout: 300
  },
  player: {
    defaultVolume: 70,
    autoplay: true,
    loop: true,
    shuffle: false,
    imageDisplayDuration: 10,
    transitionEffect: 'none'
  },
  network: {
    wifi: {
      enabled: true,
      autoConnect: true
    },
    hotspot: {
      enabled: false,
      ssid: 'PiSignage-AP',
      password: 'pisignage123'
    }
  },
  system: {
    hostname: 'pisignage',
    timezone: 'Europe/Paris',
    autoUpdate: false,
    logLevel: 'info',
    maxLogSize: 10485760 // 10MB
  },
  api: {
    enableCors: true,
    rateLimit: 100,
    maxUploadSize: 524288000, // 500MB
    allowedOrigins: ['*']
  },
  playlist: {
    autoCreateDefault: true,
    includeImages: true,
    includeVideos: true
  },
  advanced: {
    vlcArguments: ['--intf', 'http', '--http-password', 'vlc', '--fullscreen'],
    debugMode: false,
    experimentalFeatures: false
  }
}

async function ensureDirectories() {
  const settingsDir = path.dirname(SETTINGS_FILE)
  await fs.mkdir(settingsDir, { recursive: true })
  await fs.mkdir(BACKUP_DIR, { recursive: true })
}

async function loadSettings(): Promise<PiSignageSettings> {
  try {
    await ensureDirectories()
    const data = await fs.readFile(SETTINGS_FILE, 'utf-8')
    const settings = JSON.parse(data)
    
    // Merge with defaults to ensure all properties exist
    return mergeWithDefaults(settings, DEFAULT_SETTINGS)
  } catch (error) {
    // Settings file doesn't exist or is invalid, return defaults
    await saveSettings(DEFAULT_SETTINGS)
    return DEFAULT_SETTINGS
  }
}

async function saveSettings(settings: PiSignageSettings): Promise<void> {
  await ensureDirectories()
  
  // Create backup of current settings if they exist
  try {
    await fs.access(SETTINGS_FILE)
    const backup = await fs.readFile(SETTINGS_FILE, 'utf-8')
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const backupFile = path.join(BACKUP_DIR, `settings-${timestamp}.json`)
    await fs.writeFile(backupFile, backup)
    
    // Keep only last 10 backups
    const backups = await fs.readdir(BACKUP_DIR)
    const sortedBackups = backups
      .filter(f => f.startsWith('settings-') && f.endsWith('.json'))
      .sort()
      .reverse()
    
    if (sortedBackups.length > 10) {
      for (const oldBackup of sortedBackups.slice(10)) {
        await fs.unlink(path.join(BACKUP_DIR, oldBackup)).catch(() => {})
      }
    }
  } catch {
    // No existing settings file
  }
  
  await fs.writeFile(SETTINGS_FILE, JSON.stringify(settings, null, 2))
}

function mergeWithDefaults(settings: any, defaults: PiSignageSettings): PiSignageSettings {
  const merged = { ...defaults }
  
  for (const [category, categorySettings] of Object.entries(settings)) {
    if (merged[category as keyof PiSignageSettings]) {
      merged[category as keyof PiSignageSettings] = {
        ...merged[category as keyof PiSignageSettings],
        ...categorySettings
      }
    }
  }
  
  return merged
}

function validateSettings(settings: any): { valid: boolean; errors: string[] } {
  const errors: string[] = []
  
  // Validate display settings
  if (settings.display) {
    if (settings.display.brightness !== undefined) {
      const brightness = settings.display.brightness
      if (typeof brightness !== 'number' || brightness < 0 || brightness > 100) {
        errors.push('Brightness must be a number between 0 and 100')
      }
    }
    
    if (settings.display.orientation !== undefined) {
      if (!['landscape', 'portrait'].includes(settings.display.orientation)) {
        errors.push('Orientation must be "landscape" or "portrait"')
      }
    }
    
    if (settings.display.screensaverTimeout !== undefined) {
      const timeout = settings.display.screensaverTimeout
      if (typeof timeout !== 'number' || timeout < 60) {
        errors.push('Screensaver timeout must be at least 60 seconds')
      }
    }
  }
  
  // Validate player settings
  if (settings.player) {
    if (settings.player.defaultVolume !== undefined) {
      const volume = settings.player.defaultVolume
      if (typeof volume !== 'number' || volume < 0 || volume > 100) {
        errors.push('Default volume must be a number between 0 and 100')
      }
    }
    
    if (settings.player.imageDisplayDuration !== undefined) {
      const duration = settings.player.imageDisplayDuration
      if (typeof duration !== 'number' || duration < 1 || duration > 300) {
        errors.push('Image display duration must be between 1 and 300 seconds')
      }
    }
  }
  
  // Validate system settings
  if (settings.system) {
    if (settings.system.logLevel !== undefined) {
      if (!['debug', 'info', 'warn', 'error'].includes(settings.system.logLevel)) {
        errors.push('Log level must be one of: debug, info, warn, error')
      }
    }
    
    if (settings.system.maxLogSize !== undefined) {
      const size = settings.system.maxLogSize
      if (typeof size !== 'number' || size < 1048576) { // 1MB minimum
        errors.push('Max log size must be at least 1MB (1048576 bytes)')
      }
    }
  }
  
  // Validate API settings
  if (settings.api) {
    if (settings.api.rateLimit !== undefined) {
      const limit = settings.api.rateLimit
      if (typeof limit !== 'number' || limit < 1 || limit > 10000) {
        errors.push('Rate limit must be between 1 and 10000 requests per minute')
      }
    }
    
    if (settings.api.maxUploadSize !== undefined) {
      const size = settings.api.maxUploadSize
      if (typeof size !== 'number' || size < 1048576 || size > 1073741824) { // 1MB to 1GB
        errors.push('Max upload size must be between 1MB and 1GB')
      }
    }
  }
  
  return {
    valid: errors.length === 0,
    errors
  }
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const category = searchParams.get('category')
    
    const settings = await loadSettings()
    
    if (category) {
      if (settings[category as keyof PiSignageSettings]) {
        return NextResponse.json({
          success: true,
          data: {
            [category]: settings[category as keyof PiSignageSettings]
          }
        })
      } else {
        return NextResponse.json(
          { success: false, error: `Unknown settings category: ${category}` },
          { status: 400 }
        )
      }
    }
    
    return NextResponse.json({
      success: true,
      data: settings
    })
    
  } catch (error) {
    console.error('Settings GET API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to load settings' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, settings: newSettings, category } = body
    
    if (!action) {
      return NextResponse.json(
        { success: false, error: 'Action is required' },
        { status: 400 }
      )
    }
    
    switch (action) {
      case 'update':
        if (!newSettings) {
          return NextResponse.json(
            { success: false, error: 'Settings object is required for update action' },
            { status: 400 }
          )
        }
        
        // Validate settings
        const validation = validateSettings(newSettings)
        if (!validation.valid) {
          return NextResponse.json(
            { success: false, error: `Validation errors: ${validation.errors.join(', ')}` },
            { status: 400 }
          )
        }
        
        const currentSettings = await loadSettings()
        
        let updatedSettings: PiSignageSettings
        
        if (category) {
          // Update specific category
          if (!currentSettings[category as keyof PiSignageSettings]) {
            return NextResponse.json(
              { success: false, error: `Unknown settings category: ${category}` },
              { status: 400 }
            )
          }
          
          updatedSettings = {
            ...currentSettings,
            [category]: {
              ...currentSettings[category as keyof PiSignageSettings],
              ...newSettings[category] || newSettings
            }
          }
        } else {
          // Update entire settings object
          updatedSettings = mergeWithDefaults(newSettings, currentSettings)
        }
        
        await saveSettings(updatedSettings)
        
        return NextResponse.json({
          success: true,
          data: { message: 'Settings updated successfully' }
        })
      
      case 'reset':
        if (category) {
          // Reset specific category
          const currentSettings = await loadSettings()
          const updatedSettings = {
            ...currentSettings,
            [category]: DEFAULT_SETTINGS[category as keyof PiSignageSettings]
          }
          await saveSettings(updatedSettings)
          
          return NextResponse.json({
            success: true,
            data: { message: `${category} settings reset to defaults` }
          })
        } else {
          // Reset all settings
          await saveSettings(DEFAULT_SETTINGS)
          
          return NextResponse.json({
            success: true,
            data: { message: 'All settings reset to defaults' }
          })
        }
      
      case 'backup':
        const settings = await loadSettings()
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
        const backupFile = path.join(BACKUP_DIR, `manual-backup-${timestamp}.json`)
        
        await fs.writeFile(backupFile, JSON.stringify(settings, null, 2))
        
        return NextResponse.json({
          success: true,
          data: { 
            message: 'Settings backup created successfully',
            backupFile: path.basename(backupFile)
          }
        })
      
      case 'restore':
        const { backupFile } = body
        if (!backupFile) {
          return NextResponse.json(
            { success: false, error: 'Backup file name is required for restore action' },
            { status: 400 }
          )
        }
        
        const backupPath = path.join(BACKUP_DIR, backupFile)
        
        try {
          const backupData = await fs.readFile(backupPath, 'utf-8')
          const backupSettings = JSON.parse(backupData)
          
          // Validate backup settings
          const backupValidation = validateSettings(backupSettings)
          if (!backupValidation.valid) {
            return NextResponse.json(
              { success: false, error: `Invalid backup file: ${backupValidation.errors.join(', ')}` },
              { status: 400 }
            )
          }
          
          await saveSettings(mergeWithDefaults(backupSettings, DEFAULT_SETTINGS))
          
          return NextResponse.json({
            success: true,
            data: { message: 'Settings restored from backup successfully' }
          })
        } catch (error) {
          return NextResponse.json(
            { success: false, error: 'Failed to restore from backup file' },
            { status: 400 }
          )
        }
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Settings POST API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Settings operation failed' 
      },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const settings = await request.json()
    
    // Validate settings
    const validation = validateSettings(settings)
    if (!validation.valid) {
      return NextResponse.json(
        { success: false, error: `Validation errors: ${validation.errors.join(', ')}` },
        { status: 400 }
      )
    }
    
    const mergedSettings = mergeWithDefaults(settings, DEFAULT_SETTINGS)
    await saveSettings(mergedSettings)
    
    return NextResponse.json({
      success: true,
      data: { message: 'Settings updated successfully' }
    })
    
  } catch (error) {
    console.error('Settings PUT API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to update settings' 
      },
      { status: 500 }
    )
  }
}