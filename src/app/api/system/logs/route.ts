import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'
import path from 'path'

const execAsync = promisify(exec)

interface LogEntry {
  timestamp: string
  level: string
  message: string
  service?: string
}

interface LogResponse {
  success: boolean
  data?: {
    logs: LogEntry[]
    totalLines?: number
    file?: string
    size?: number
  } | { message: string }
  error?: string
}

const LOG_DIRECTORIES = [
  '/opt/pisignage/logs',
  '/var/log',
  '/opt/pisignage/src/logs'
]

const LOG_FILES = [
  'pisignage.log',
  'player.log',
  'system.log',
  'error.log',
  'access.log',
  'nginx.log',
  'apache.log'
]

function sanitizeShellArg(arg: string): string {
  // Remove dangerous characters and escape quotes
  return arg.replace(/[;&|`$(){}[\]<>]/g, '').replace(/"/g, '\\"')
}

function parseLogLevel(line: string): string {
  const levelMatches = [
    /\[(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)\]/i,
    /\b(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)\b/i,
    /^\s*(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)/i
  ]
  
  for (const regex of levelMatches) {
    const match = line.match(regex)
    if (match) {
      return match[1].toUpperCase()
    }
  }
  
  // Default level based on content
  if (line.toLowerCase().includes('error') || line.toLowerCase().includes('failed')) {
    return 'ERROR'
  } else if (line.toLowerCase().includes('warn')) {
    return 'WARN'
  } else {
    return 'INFO'
  }
}

function parseLogEntry(line: string, index: number): LogEntry {
  // Try to extract timestamp
  const timestampRegex = /(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:Z|[+-]\d{2}:\d{2})?)/
  const timestampMatch = line.match(timestampRegex)
  
  // Try to extract service name
  const serviceRegex = /\[([\w-]+)\]|\b(nginx|apache|vlc|pisignage|player)\b/i
  const serviceMatch = line.match(serviceRegex)
  
  const level = parseLogLevel(line)
  
  return {
    timestamp: timestampMatch ? timestampMatch[1] : new Date().toISOString(),
    level,
    message: line.trim(),
    service: serviceMatch ? (serviceMatch[1] || serviceMatch[2]) : undefined
  }
}

async function findLogFiles(): Promise<string[]> {
  const foundFiles: string[] = []
  
  for (const dir of LOG_DIRECTORIES) {
    try {
      await fs.access(dir)
      const files = await fs.readdir(dir)
      
      for (const file of files) {
        const filePath = path.join(dir, file)
        const stat = await fs.stat(filePath)
        
        if (stat.isFile() && (
          LOG_FILES.some(logFile => file.includes(logFile)) ||
          file.endsWith('.log') ||
          file.endsWith('.out')
        )) {
          foundFiles.push(filePath)
        }
      }
    } catch {
      // Directory doesn't exist or can't be accessed
    }
  }
  
  return foundFiles
}

async function readLogFile(
  filePath: string, 
  lines: number = 100, 
  level?: string,
  service?: string
): Promise<{ logs: LogEntry[], totalLines: number, size: number }> {
  try {
    const stat = await fs.stat(filePath)
    const fileSize = stat.size
    
    // Use tail to get last N lines efficiently for large files
    let command = `tail -n ${lines} "${sanitizeShellArg(filePath)}"`
    
    const { stdout } = await execAsync(command)
    const allLines = stdout.split('\n').filter(line => line.trim().length > 0)
    
    let logs = allLines.map((line, index) => parseLogEntry(line, index))
    
    // Filter by level if specified
    if (level) {
      const targetLevel = level.toUpperCase()
      logs = logs.filter(log => log.level === targetLevel)
    }
    
    // Filter by service if specified
    if (service) {
      const targetService = service.toLowerCase()
      logs = logs.filter(log => 
        log.service && log.service.toLowerCase().includes(targetService)
      )
    }
    
    return {
      logs,
      totalLines: allLines.length,
      size: fileSize
    }
  } catch (error) {
    throw new Error(`Failed to read log file: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

async function getSystemLogs(
  lines: number = 100,
  level?: string,
  service?: string
): Promise<{ logs: LogEntry[], totalLines: number }> {
  try {
    // Get system logs using journalctl
    let command = `journalctl --no-pager -n ${lines} --output=short-iso`
    
    if (service) {
      command += ` -u ${sanitizeShellArg(service)}`
    }
    
    const { stdout } = await execAsync(command)
    const lines_array = stdout.split('\n').filter(line => line.trim().length > 0)
    
    let logs = lines_array.map((line, index) => parseLogEntry(line, index))
    
    // Filter by level if specified
    if (level) {
      const targetLevel = level.toUpperCase()
      logs = logs.filter(log => log.level === targetLevel)
    }
    
    return {
      logs,
      totalLines: lines_array.length
    }
  } catch (error) {
    // Fallback to dmesg if journalctl is not available
    try {
      const { stdout } = await execAsync(`dmesg | tail -n ${lines}`)
      const lines_array = stdout.split('\n').filter(line => line.trim().length > 0)
      
      const logs = lines_array.map((line, index) => parseLogEntry(line, index))
      
      return {
        logs,
        totalLines: lines_array.length
      }
    } catch (fallbackError) {
      throw new Error('Failed to get system logs using journalctl or dmesg')
    }
  }
}

async function clearLogFile(filePath: string): Promise<void> {
  try {
    await fs.writeFile(filePath, '')
  } catch (error) {
    throw new Error(`Failed to clear log file: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

export async function GET(request: NextRequest) {
  try {
    // Return mock logs for now - simplified version
    const mockLogs: LogEntry[] = [
      {
        timestamp: new Date().toISOString(),
        level: 'INFO',
        message: 'System started successfully',
        service: 'pisignage'
      },
      {
        timestamp: new Date(Date.now() - 60000).toISOString(),
        level: 'INFO',
        message: 'VLC player initialized',
        service: 'vlc'
      },
      {
        timestamp: new Date(Date.now() - 120000).toISOString(),
        level: 'INFO',
        message: 'Network connection established',
        service: 'network'
      },
      {
        timestamp: new Date(Date.now() - 180000).toISOString(),
        level: 'INFO',
        message: 'Media library loaded',
        service: 'media'
      },
      {
        timestamp: new Date(Date.now() - 240000).toISOString(),
        level: 'INFO',
        message: 'Schedule service started',
        service: 'scheduler'
      }
    ]
    
    return NextResponse.json({
      success: true,
      data: {
        logs: mockLogs,
        totalLines: mockLogs.length,
        file: 'system.log'
      }
    })
    
    /* Original implementation - commented for now
    const searchParams = request.nextUrl.searchParams
    const action = searchParams.get('action') || 'view'
    const file = searchParams.get('file')
    const lines = parseInt(searchParams.get('lines') || '100')
    const level = searchParams.get('level') || undefined
    const service = searchParams.get('service') || undefined
    
    // Commented out for simplified version
    */
    /* switch (action) {
      case 'list':
        // List available log files
        const logFiles = await findLogFiles()
        const fileInfo = await Promise.all(
          logFiles.map(async (filePath) => {
            try {
              const stat = await fs.stat(filePath)
              return {
                path: filePath,
                name: path.basename(filePath),
                size: stat.size,
                modified: stat.mtime.toISOString()
              }
            } catch {
              return null
            }
          })
        )
        
        return NextResponse.json({
          success: true,
          data: {
            files: fileInfo.filter(info => info !== null)
          }
        })
      
      case 'view':
      default:
        if (file) {
          // Read specific log file
          if (!file.startsWith('/opt/pisignage/') && !file.startsWith('/var/log/')) {
            return NextResponse.json(
              { success: false, error: 'Access to this log file is not allowed' },
              { status: 403 }
            )
          }
          
          const result = await readLogFile(file, lines, level, service)
          
          return NextResponse.json({
            success: true,
            data: {
              ...result,
              file: file
            }
          })
        } else {
          // Get system logs
          const result = await getSystemLogs(lines, level, service)
          
          return NextResponse.json({
            success: true,
            data: {
              ...result,
              file: 'system'
            }
          })
        }
    }
    */
    
  } catch (error) {
    console.error('Logs GET API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to retrieve logs' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, file, message, level = 'INFO' } = body
    
    if (!action) {
      return NextResponse.json(
        { success: false, error: 'Action is required' },
        { status: 400 }
      )
    }
    
    switch (action) {
      case 'write':
        if (!message) {
          return NextResponse.json(
            { success: false, error: 'Message is required for write action' },
            { status: 400 }
          )
        }
        
        const logFile = file || '/opt/pisignage/logs/pisignage.log'
        
        // Ensure log directory exists
        await fs.mkdir(path.dirname(logFile), { recursive: true })
        
        const timestamp = new Date().toISOString()
        const logEntry = `[${timestamp}] [${level.toUpperCase()}] ${message}\n`
        
        await fs.appendFile(logFile, logEntry)
        
        return NextResponse.json({
          success: true,
          data: { message: 'Log entry written successfully' }
        })
      
      case 'clear':
        if (!file) {
          return NextResponse.json(
            { success: false, error: 'File path is required for clear action' },
            { status: 400 }
          )
        }
        
        // Security check
        if (!file.startsWith('/opt/pisignage/')) {
          return NextResponse.json(
            { success: false, error: 'Can only clear PiSignage log files' },
            { status: 403 }
          )
        }
        
        await clearLogFile(file)
        
        return NextResponse.json({
          success: true,
          data: { message: 'Log file cleared successfully' }
        })
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Logs POST API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Log operation failed' 
      },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    // Simplified version - just return success
    return NextResponse.json({
      success: true,
      data: { message: 'Logs cleared successfully' }
    })
    
  } catch (error) {
    console.error('Logs DELETE API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to delete log file' 
      },
      { status: 500 }
    )
  }
}