import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import os from 'os'
import fs from 'fs/promises'

const execAsync = promisify(exec)

// Helper to calculate CPU usage percentage
function getCPUUsage(): Promise<number> {
  return new Promise((resolve) => {
    const startMeasure = process.cpuUsage()
    const startTime = process.hrtime()
    
    setTimeout(() => {
      const endMeasure = process.cpuUsage(startMeasure)
      const endTime = process.hrtime(startTime)
      
      const totalTime = endTime[0] * 1000000 + endTime[1] / 1000
      const totalUsage = endMeasure.user + endMeasure.system
      
      const percentage = (totalUsage / totalTime) * 100
      resolve(Math.min(100, Math.round(percentage * 10) / 10))
    }, 100)
  })
}

export async function GET(request: NextRequest) {
  try {
    // Get CPU usage percentage
    const cpuUsage = await getCPUUsage()
    
    // Get memory info
    const totalMemory = os.totalmem()
    const freeMemory = os.freemem()
    const usedMemory = totalMemory - freeMemory
    const memoryPercentage = Math.round((usedMemory / totalMemory) * 100)
    
    // Get CPU temperature (Raspberry Pi specific)
    let temperature = 40 // Default value
    try {
      const { stdout } = await execAsync('vcgencmd measure_temp')
      temperature = parseFloat(stdout.replace("temp=", "").replace("'C\n", ""))
    } catch (e) {
      // Not a Raspberry Pi or vcgencmd not available
    }
    
    // Get disk usage
    let diskUsed = 0
    let diskTotal = 1
    let diskPercentage = 0
    try {
      const { stdout } = await execAsync("df -B1 / | awk 'NR==2 {print $2,$3}'")
      const [total, used] = stdout.trim().split(' ').map(Number)
      diskTotal = total
      diskUsed = used
      diskPercentage = Math.round((used / total) * 100)
    } catch (e) {
      // Error getting disk usage
    }
    
    // Get VLC status
    let vlcStatus: 'playing' | 'paused' | 'stopped' = 'stopped'
    let currentMedia = ''
    try {
      const { stdout } = await execAsync('pgrep vlc')
      if (stdout.trim()) {
        vlcStatus = 'playing'
        // Try to get current media
        try {
          const { stdout: mediaInfo } = await execAsync("ps aux | grep vlc | grep -o '/[^ ]*\\.\\(mp4\\|avi\\|mkv\\|mov\\)' | head -1")
          currentMedia = mediaInfo.trim()
        } catch (e) {}
      }
    } catch (e) {
      // VLC not running
    }
    
    // Get network info
    let networkInfo = {
      ip: 'N/A',
      hostname: os.hostname()
    }
    try {
      const { stdout } = await execAsync("hostname -I | awk '{print $1}'")
      networkInfo.ip = stdout.trim() || 'N/A'
    } catch (e) {}
    
    // Format uptime
    const uptimeSeconds = os.uptime()
    const days = Math.floor(uptimeSeconds / 86400)
    const hours = Math.floor((uptimeSeconds % 86400) / 3600)
    const minutes = Math.floor((uptimeSeconds % 3600) / 60)
    const uptimeString = `${days}j ${hours}h ${minutes}m`
    
    return NextResponse.json({
      cpu: cpuUsage, // Single number for CPU percentage
      memory: {
        used: usedMemory,
        total: totalMemory,
        percentage: memoryPercentage
      },
      disk: {
        used: diskUsed,
        total: diskTotal,
        percentage: diskPercentage
      },
      temperature: temperature,
      vlcStatus: vlcStatus,
      currentMedia: currentMedia,
      uptime: uptimeString,
      network: networkInfo
    })
  } catch (error) {
    console.error('System API error:', error)
    return NextResponse.json(
      { 
        cpu: 0,
        memory: { used: 0, total: 1, percentage: 0 },
        disk: { used: 0, total: 1, percentage: 0 },
        temperature: 0,
        vlcStatus: 'stopped',
        currentMedia: '',
        uptime: 'N/A',
        network: { ip: 'N/A', hostname: 'N/A' }
      },
      { status: 200 } // Return 200 with default values to avoid breaking the UI
    )
  }
}