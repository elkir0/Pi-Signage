import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import os from 'os'
import fs from 'fs/promises'

const execAsync = promisify(exec)

export async function GET(request: NextRequest) {
  try {
    // Get system information
    const cpuInfo = os.cpus()
    const totalMemory = os.totalmem()
    const freeMemory = os.freemem()
    const uptime = os.uptime()
    
    // Get CPU temperature (Raspberry Pi specific)
    let temperature = null
    try {
      const { stdout } = await execAsync('vcgencmd measure_temp')
      temperature = parseFloat(stdout.replace("temp=", "").replace("'C\n", ""))
    } catch (e) {
      // Not a Raspberry Pi or vcgencmd not available
    }
    
    // Get disk usage
    let diskUsage = null
    try {
      const { stdout } = await execAsync("df -h / | awk 'NR==2 {print $5}'")
      diskUsage = stdout.trim()
    } catch (e) {
      // Error getting disk usage
    }
    
    // Get VLC status
    let vlcStatus = 'stopped'
    try {
      const { stdout } = await execAsync('pgrep vlc')
      if (stdout.trim()) {
        vlcStatus = 'playing'
      }
    } catch (e) {
      // VLC not running
    }
    
    return NextResponse.json({
      system: {
        platform: os.platform(),
        arch: os.arch(),
        hostname: os.hostname(),
        uptime: Math.floor(uptime),
      },
      cpu: {
        model: cpuInfo[0]?.model || 'Unknown',
        cores: cpuInfo.length,
        usage: process.cpuUsage(),
        temperature,
      },
      memory: {
        total: totalMemory,
        free: freeMemory,
        used: totalMemory - freeMemory,
        percentage: Math.round(((totalMemory - freeMemory) / totalMemory) * 100),
      },
      disk: {
        usage: diskUsage,
      },
      vlc: {
        status: vlcStatus,
      },
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to get system information' },
      { status: 500 }
    )
  }
}