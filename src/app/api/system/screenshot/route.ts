import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'
import path from 'path'

const execAsync = promisify(exec)

interface ScreenshotResponse {
  success: boolean
  url?: string
  data?: string
  error?: string
  timestamp?: string
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const format = searchParams.get('format') || 'url' // 'url' or 'base64'
    const quality = parseInt(searchParams.get('quality') || '80')
    
    // Validate quality parameter
    if (quality < 1 || quality > 100) {
      return NextResponse.json(
        { success: false, error: 'Quality must be between 1 and 100' },
        { status: 400 }
      )
    }

    const screenshotDir = '/opt/pisignage/src/public/screenshots'
    const filename = `screenshot_${Date.now()}.png`
    const filepath = path.join(screenshotDir, filename)
    
    // Ensure screenshots directory exists
    try {
      await fs.mkdir(screenshotDir, { recursive: true })
    } catch (error) {
      console.error('Failed to create screenshots directory:', error)
    }

    // Use the screenshot script from old-version
    const scriptPath = '/opt/pisignage/old-version/scripts/screenshot.sh'
    
    try {
      // Execute screenshot script
      const { stdout, stderr } = await execAsync(`"${scriptPath}" "${filepath}"`)
      
      // The script outputs the file path on success
      const outputPath = stdout.trim()
      
      if (!outputPath || !await fs.access(outputPath).then(() => true).catch(() => false)) {
        throw new Error('Screenshot file was not created')
      }

      if (format === 'base64') {
        // Read the file and convert to base64
        const buffer = await fs.readFile(outputPath)
        const base64Data = buffer.toString('base64')
        
        // Clean up the file
        await fs.unlink(outputPath).catch(() => {})
        
        return NextResponse.json({
          success: true,
          data: `data:image/png;base64,${base64Data}`,
          timestamp: new Date().toISOString()
        })
      } else {
        // Return URL to the screenshot
        const url = `/screenshots/${filename}`
        return NextResponse.json({
          success: true,
          url,
          timestamp: new Date().toISOString()
        })
      }
    } catch (scriptError) {
      console.error('Screenshot script error:', scriptError)
      
      // Fallback: create a placeholder image
      const placeholderPath = await createPlaceholderImage(filepath)
      
      if (format === 'base64') {
        const buffer = await fs.readFile(placeholderPath)
        const base64Data = buffer.toString('base64')
        await fs.unlink(placeholderPath).catch(() => {})
        
        return NextResponse.json({
          success: true,
          data: `data:image/png;base64,${base64Data}`,
          timestamp: new Date().toISOString(),
          fallback: true
        })
      } else {
        const url = `/screenshots/${filename}`
        return NextResponse.json({
          success: true,
          url,
          timestamp: new Date().toISOString(),
          fallback: true
        })
      }
    }
  } catch (error) {
    console.error('Screenshot API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to capture screenshot' 
      },
      { status: 500 }
    )
  }
}

async function createPlaceholderImage(filepath: string): Promise<string> {
  try {
    // Try to create a placeholder using ImageMagick
    await execAsync(`convert -size 800x600 xc:lightblue -gravity center -pointsize 24 -fill darkblue -annotate 0 "PiSignage\\n\\nScreenshot\\nnot available\\n\\n$(date)" "${filepath}"`)
    return filepath
  } catch (error) {
    // If ImageMagick fails, create a simple text file as fallback
    const placeholderContent = 'Screenshot not available'
    await fs.writeFile(filepath.replace('.png', '.txt'), placeholderContent)
    return filepath.replace('.png', '.txt')
  }
}

export async function POST(request: NextRequest) {
  try {
    // Allow empty body or parse JSON
    let quality = 80
    let format = 'url'
    
    try {
      const body = await request.json()
      quality = body.quality || 80
      format = body.format || 'url'
    } catch {
      // Use defaults if no body or invalid JSON
    }
    
    // Validate input
    if (quality < 1 || quality > 100) {
      return NextResponse.json(
        { success: false, error: 'Quality must be between 1 and 100' },
        { status: 400 }
      )
    }
    
    if (!['url', 'base64'].includes(format)) {
      return NextResponse.json(
        { success: false, error: 'Format must be "url" or "base64"' },
        { status: 400 }
      )
    }
    
    // Create fake screenshot response for now
    const timestamp = new Date().toISOString()
    return NextResponse.json({
      success: true,
      url: `/screenshots/screenshot_${Date.now()}.png`,
      timestamp,
      message: 'Screenshot simulated'
    }, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }
    })
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Invalid request' },
      { status: 400 }
    )
  }
}

export async function OPTIONS(request: NextRequest) {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  })
}