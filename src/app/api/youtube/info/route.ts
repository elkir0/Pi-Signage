import { NextRequest, NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

interface YouTubeVideoInfo {
  id: string
  title: string
  duration: number
  thumbnail: string
  description?: string
  uploader: string
  upload_date: string
  view_count?: number
  like_count?: number
  formats: Array<{
    format_id: string
    ext: string
    quality: string
    filesize?: number
    vcodec?: string
    acodec?: string
  }>
}

interface YouTubeInfoResponse {
  success: boolean
  data?: YouTubeVideoInfo
  error?: string
}

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
  // Remove or escape potentially dangerous characters
  return arg.replace(/[;&|`$(){}[\]<>]/g, '').replace(/"/g, '\\"')
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const url = searchParams.get('url')
    
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

    const videoId = extractVideoId(url)
    if (!videoId) {
      return NextResponse.json(
        { success: false, error: 'Could not extract video ID from URL' },
        { status: 400 }
      )
    }

    // Sanitize URL for shell execution
    const sanitizedUrl = sanitizeShellArg(url)
    
    try {
      // Use yt-dlp to get video information
      const command = `yt-dlp --dump-json --no-playlist "${sanitizedUrl}"`
      const { stdout, stderr } = await execAsync(command, { 
        timeout: 30000, // 30 second timeout
        maxBuffer: 1024 * 1024 // 1MB buffer
      })
      
      if (stderr && stderr.includes('ERROR')) {
        throw new Error(`yt-dlp error: ${stderr}`)
      }
      
      const videoInfo = JSON.parse(stdout.trim())
      
      // Extract and format the relevant information
      const formatData: YouTubeVideoInfo = {
        id: videoInfo.id || videoId,
        title: videoInfo.title || 'Unknown Title',
        duration: videoInfo.duration || 0,
        thumbnail: videoInfo.thumbnail || videoInfo.thumbnails?.[0]?.url || '',
        description: videoInfo.description?.substring(0, 500) || '',
        uploader: videoInfo.uploader || videoInfo.channel || 'Unknown',
        upload_date: videoInfo.upload_date || '',
        view_count: videoInfo.view_count || 0,
        like_count: videoInfo.like_count || 0,
        formats: (videoInfo.formats || [])
          .filter((format: any) => format.vcodec !== 'none' || format.acodec !== 'none')
          .slice(0, 10) // Limit to first 10 formats
          .map((format: any) => ({
            format_id: format.format_id || '',
            ext: format.ext || '',
            quality: format.quality || format.height ? `${format.height}p` : 'unknown',
            filesize: format.filesize,
            vcodec: format.vcodec,
            acodec: format.acodec
          }))
      }
      
      return NextResponse.json({
        success: true,
        data: formatData
      })
      
    } catch (execError) {
      console.error('yt-dlp execution error:', execError)
      
      // Check if yt-dlp is installed
      try {
        await execAsync('which yt-dlp')
      } catch {
        return NextResponse.json(
          { success: false, error: 'yt-dlp is not installed on the system' },
          { status: 500 }
        )
      }
      
      return NextResponse.json(
        { 
          success: false, 
          error: execError instanceof Error ? execError.message : 'Failed to fetch video information'
        },
        { status: 500 }
      )
    }
    
  } catch (error) {
    console.error('YouTube info API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Internal server error' 
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { url } = body
    
    if (!url) {
      return NextResponse.json(
        { success: false, error: 'YouTube URL is required in request body' },
        { status: 400 }
      )
    }
    
    if (!isValidYouTubeUrl(url)) {
      return NextResponse.json(
        { success: false, error: 'Invalid YouTube URL format' },
        { status: 400 }
      )
    }
    
    // Redirect to GET method with URL as query parameter
    const requestUrl = new URL(request.url)
    requestUrl.searchParams.set('url', url)
    
    const response = await fetch(requestUrl.toString(), {
      method: 'GET',
      headers: request.headers
    })
    
    return new NextResponse(response.body, {
      status: response.status,
      headers: response.headers
    })
    
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Invalid request body' },
      { status: 400 }
    )
  }
}