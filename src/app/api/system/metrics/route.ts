import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'
import os from 'os'

const execAsync = promisify(exec)

interface SystemMetrics {
  timestamp: string
  cpu: {
    usage: number
    temperature?: number
    frequency?: number
    loadAverage: number[]
    cores: number
    model: string
  }
  memory: {
    total: number
    free: number
    used: number
    available: number
    percentage: number
    swap?: {
      total: number
      free: number
      used: number
    }
  }
  disk: {
    total: number
    free: number
    used: number
    percentage: number
    mountPoint: string
  }
  network?: {
    interfaces: Array<{
      name: string
      rx_bytes?: number
      tx_bytes?: number
      rx_packets?: number
      tx_packets?: number
    }>
  }
  raspberry?: {
    temperature: number
    voltage?: number
    throttling?: boolean
    model?: string
  }
  processes: {
    total: number
    running: number
    vlc?: boolean
    nginx?: boolean
  }
  uptime: number
}

interface MetricsResponse {
  success: boolean
  data?: SystemMetrics | SystemMetrics[]
  error?: string
}

async function getCPUUsage(): Promise<number> {
  try {
    // Get CPU usage using top command
    const { stdout } = await execAsync("top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'")
    const usage = parseFloat(stdout.trim())
    return isNaN(usage) ? 0 : Math.round(usage * 100) / 100
  } catch {
    // Fallback: calculate from /proc/stat
    try {
      const stat1 = await fs.readFile('/proc/stat', 'utf-8')
      await new Promise(resolve => setTimeout(resolve, 100))
      const stat2 = await fs.readFile('/proc/stat', 'utf-8')
      
      const getCpuTimes = (stat: string) => {
        const line = stat.split('\n')[0]
        const times = line.split(' ').slice(2).map(Number)
        return {
          idle: times[3],
          total: times.reduce((a, b) => a + b, 0)
        }
      }
      
      const times1 = getCpuTimes(stat1)
      const times2 = getCpuTimes(stat2)
      
      const idleDiff = times2.idle - times1.idle
      const totalDiff = times2.total - times1.total
      
      const usage = 100 - (idleDiff / totalDiff * 100)
      return Math.round(usage * 100) / 100
    } catch {
      return 0
    }
  }
}

async function getCPUTemperature(): Promise<number | undefined> {
  try {
    // Raspberry Pi specific
    const { stdout } = await execAsync('vcgencmd measure_temp')
    const temp = parseFloat(stdout.replace("temp=", "").replace("'C\n", ""))
    return isNaN(temp) ? undefined : temp
  } catch {
    try {
      // Generic Linux thermal zone
      const thermal = await fs.readFile('/sys/class/thermal/thermal_zone0/temp', 'utf-8')
      const temp = parseInt(thermal.trim()) / 1000
      return isNaN(temp) ? undefined : temp
    } catch {
      return undefined
    }
  }
}

async function getCPUFrequency(): Promise<number | undefined> {
  try {
    const { stdout } = await execAsync('vcgencmd measure_clock arm')
    const freq = parseInt(stdout.replace('frequency(48)=', '')) / 1000000
    return isNaN(freq) ? undefined : freq
  } catch {
    try {
      const freq = await fs.readFile('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq', 'utf-8')
      const freqMhz = parseInt(freq.trim()) / 1000
      return isNaN(freqMhz) ? undefined : freqMhz
    } catch {
      return undefined
    }
  }
}

async function getMemoryInfo(): Promise<any> {
  try {
    const meminfo = await fs.readFile('/proc/meminfo', 'utf-8')
    const lines = meminfo.split('\n')
    
    const getValue = (key: string) => {
      const line = lines.find(l => l.startsWith(key))
      if (line) {
        const match = line.match(/:\s*(\d+)\s*kB/)
        return match ? parseInt(match[1]) * 1024 : 0
      }
      return 0
    }
    
    const total = getValue('MemTotal')
    const free = getValue('MemFree')
    const available = getValue('MemAvailable') || free
    const buffers = getValue('Buffers')
    const cached = getValue('Cached')
    const used = total - free - buffers - cached
    
    const swapTotal = getValue('SwapTotal')
    const swapFree = getValue('SwapFree')
    const swapUsed = swapTotal - swapFree
    
    return {
      total,
      free,
      used,
      available,
      percentage: Math.round((used / total) * 100),
      swap: {
        total: swapTotal,
        free: swapFree,
        used: swapUsed
      }
    }
  } catch {
    // Fallback to os module
    const total = os.totalmem()
    const free = os.freemem()
    const used = total - free
    
    return {
      total,
      free,
      used,
      available: free,
      percentage: Math.round((used / total) * 100)
    }
  }
}

async function getDiskInfo(): Promise<any> {
  try {
    const { stdout } = await execAsync("df -h / | awk 'NR==2 {printf \"%.0f %.0f %.0f %s\", $2*1024*1024*1024/1073741824, $3*1024*1024*1024/1073741824, $4*1024*1024*1024/1073741824, $5}'")
    const [total, used, free, percentage] = stdout.trim().split(' ')
    
    return {
      total: parseFloat(total) * 1024 * 1024 * 1024,
      used: parseFloat(used) * 1024 * 1024 * 1024,
      free: parseFloat(free) * 1024 * 1024 * 1024,
      percentage: parseInt(percentage.replace('%', '')),
      mountPoint: '/'
    }
  } catch {
    return {
      total: 0,
      used: 0,
      free: 0,
      percentage: 0,
      mountPoint: '/'
    }
  }
}

async function getNetworkInfo(): Promise<any> {
  try {
    const { stdout } = await execAsync('cat /proc/net/dev')
    const lines = stdout.split('\n').slice(2) // Skip header lines
    
    const interfaces = lines
      .filter(line => line.trim().length > 0)
      .map(line => {
        const parts = line.trim().split(/\s+/)
        const name = parts[0].replace(':', '')
        
        if (name === 'lo') return null // Skip loopback
        
        return {
          name,
          rx_bytes: parseInt(parts[1]) || 0,
          rx_packets: parseInt(parts[2]) || 0,
          tx_bytes: parseInt(parts[9]) || 0,
          tx_packets: parseInt(parts[10]) || 0
        }
      })
      .filter(iface => iface !== null)
    
    return { interfaces }
  } catch {
    return { interfaces: [] }
  }
}

async function getRaspberryPiInfo(): Promise<any> {
  try {
    const temperature = await getCPUTemperature()
    
    let voltage: number | undefined
    try {
      const { stdout } = await execAsync('vcgencmd measure_volts core')
      voltage = parseFloat(stdout.replace('volt=', '').replace('V\n', ''))
    } catch {}
    
    let throttling: boolean | undefined
    try {
      const { stdout } = await execAsync('vcgencmd get_throttled')
      const throttleValue = stdout.replace('throttled=', '').trim()
      throttling = throttleValue !== '0x0'
    } catch {}
    
    let model: string | undefined
    try {
      const modelInfo = await fs.readFile('/proc/device-tree/model', 'utf-8')
      model = modelInfo.replace(/\0/g, '').trim()
    } catch {}
    
    return {
      temperature,
      voltage,
      throttling,
      model
    }
  } catch {
    return undefined
  }
}

async function getProcessInfo(): Promise<any> {
  try {
    const { stdout: psOutput } = await execAsync('ps aux | wc -l')
    const total = parseInt(psOutput.trim()) - 1 // Subtract header line
    
    const { stdout: runningOutput } = await execAsync("ps aux | awk '$8 ~ /^[Rr]/ {count++} END {print count+0}'")
    const running = parseInt(runningOutput.trim())
    
    let vlc = false
    let nginx = false
    
    try {
      await execAsync('pgrep vlc')
      vlc = true
    } catch {}
    
    try {
      await execAsync('pgrep nginx')
      nginx = true
    } catch {}
    
    return {
      total,
      running,
      vlc,
      nginx
    }
  } catch {
    return {
      total: 0,
      running: 0,
      vlc: false,
      nginx: false
    }
  }
}

async function collectMetrics(): Promise<SystemMetrics> {
  const [
    cpuUsage,
    cpuTemp,
    cpuFreq,
    memoryInfo,
    diskInfo,
    networkInfo,
    raspberryInfo,
    processInfo
  ] = await Promise.all([
    getCPUUsage(),
    getCPUTemperature(),
    getCPUFrequency(),
    getMemoryInfo(),
    getDiskInfo(),
    getNetworkInfo(),
    getRaspberryPiInfo(),
    getProcessInfo()
  ])
  
  const cpuInfo = os.cpus()
  const loadAverage = os.loadavg()
  
  return {
    timestamp: new Date().toISOString(),
    cpu: {
      usage: cpuUsage,
      temperature: cpuTemp,
      frequency: cpuFreq,
      loadAverage,
      cores: cpuInfo.length,
      model: cpuInfo[0]?.model || 'Unknown'
    },
    memory: memoryInfo,
    disk: diskInfo,
    network: networkInfo,
    raspberry: raspberryInfo,
    processes: processInfo,
    uptime: os.uptime()
  }
}

// Store historical metrics (in memory for now)
const metricsHistory: SystemMetrics[] = []
const MAX_HISTORY_ENTRIES = 100

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const action = searchParams.get('action') || 'current'
    const limit = parseInt(searchParams.get('limit') || '10')
    
    switch (action) {
      case 'current':
        const currentMetrics = await collectMetrics()
        
        // Store in history
        metricsHistory.push(currentMetrics)
        if (metricsHistory.length > MAX_HISTORY_ENTRIES) {
          metricsHistory.shift()
        }
        
        return NextResponse.json({
          success: true,
          data: currentMetrics
        })
      
      case 'history':
        const historyLimit = Math.min(Math.max(1, limit), MAX_HISTORY_ENTRIES)
        const recentMetrics = metricsHistory.slice(-historyLimit)
        
        return NextResponse.json({
          success: true,
          data: recentMetrics
        })
      
      case 'summary':
        if (metricsHistory.length === 0) {
          return NextResponse.json({
            success: true,
            data: {
              message: 'No metrics history available',
              count: 0
            }
          })
        }
        
        const latest = metricsHistory[metricsHistory.length - 1]
        const avgCpu = metricsHistory.reduce((sum, m) => sum + m.cpu.usage, 0) / metricsHistory.length
        const avgMemory = metricsHistory.reduce((sum, m) => sum + m.memory.percentage, 0) / metricsHistory.length
        
        return NextResponse.json({
          success: true,
          data: {
            latest,
            averages: {
              cpu: Math.round(avgCpu * 100) / 100,
              memory: Math.round(avgMemory * 100) / 100
            },
            count: metricsHistory.length,
            timespan: metricsHistory.length > 1 ? {
              start: metricsHistory[0].timestamp,
              end: latest.timestamp
            } : undefined
          }
        })
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Metrics API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to collect metrics' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action } = body
    
    switch (action) {
      case 'clear':
        metricsHistory.length = 0
        return NextResponse.json({
          success: true,
          data: { message: 'Metrics history cleared' }
        })
      
      case 'collect':
        const metrics = await collectMetrics()
        metricsHistory.push(metrics)
        if (metricsHistory.length > MAX_HISTORY_ENTRIES) {
          metricsHistory.shift()
        }
        
        return NextResponse.json({
          success: true,
          data: metrics
        })
      
      default:
        return NextResponse.json(
          { success: false, error: `Unknown action: ${action}` },
          { status: 400 }
        )
    }
    
  } catch (error) {
    console.error('Metrics POST API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Metrics operation failed' 
      },
      { status: 500 }
    )
  }
}