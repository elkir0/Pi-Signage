import { NextRequest, NextResponse } from 'next/server'
import fs from 'fs/promises'
import path from 'path'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)
const MEDIA_PATH = process.env.MEDIA_PATH || '/opt/pisignage/media'
const THUMBNAILS_PATH = process.env.THUMBNAILS_PATH || '/opt/pisignage/public/thumbnails'

// Supported media formats
const SUPPORTED_FORMATS = {
  video: ['.mp4', '.avi', '.mkv', '.webm', '.mov', '.flv'],
  image: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'],
  audio: ['.mp3', '.wav', '.ogg', '.m4a']
}

async function generateThumbnail(filePath: string, outputPath: string) {
  try {
    const ext = path.extname(filePath).toLowerCase()
    
    if (SUPPORTED_FORMATS.video.includes(ext)) {
      // Generate video thumbnail using ffmpeg
      await execAsync(
        `ffmpeg -i "${filePath}" -vf "thumbnail,scale=320:240" -frames:v 1 "${outputPath}" -y`
      )
    } else if (SUPPORTED_FORMATS.image.includes(ext)) {
      // Copy image as its own thumbnail or resize with ffmpeg
      await execAsync(
        `ffmpeg -i "${filePath}" -vf "scale=320:240" "${outputPath}" -y`
      )
    }
  } catch (error) {
    console.error('Failed to generate thumbnail:', error)
  }
}

export async function GET(request: NextRequest) {
  try {
    await fs.mkdir(MEDIA_PATH, { recursive: true })
    await fs.mkdir(THUMBNAILS_PATH, { recursive: true })
    
    const files = await fs.readdir(MEDIA_PATH)
    
    const media = await Promise.all(
      files.map(async (file) => {
        const filePath = path.join(MEDIA_PATH, file)
        const stats = await fs.stat(filePath)
        
        if (!stats.isFile()) return null
        
        const ext = path.extname(file).toLowerCase()
        let type = 'unknown'
        
        if (SUPPORTED_FORMATS.video.includes(ext)) type = 'video'
        else if (SUPPORTED_FORMATS.image.includes(ext)) type = 'image'
        else if (SUPPORTED_FORMATS.audio.includes(ext)) type = 'audio'
        
        // Generate thumbnail if it doesn't exist
        const thumbnailName = `${path.basename(file, ext)}_thumb.jpg`
        const thumbnailPath = path.join(THUMBNAILS_PATH, thumbnailName)
        
        try {
          await fs.access(thumbnailPath)
        } catch {
          // Thumbnail doesn't exist, generate it
          await generateThumbnail(filePath, thumbnailPath)
        }
        
        return {
          id: file,
          name: file,
          type,
          size: stats.size,
          createdAt: stats.birthtime,
          modifiedAt: stats.mtime,
          thumbnail: `/thumbnails/${thumbnailName}`,
          path: `/media/${file}`
        }
      })
    )
    
    return NextResponse.json({
      media: media.filter(Boolean),
      total: media.filter(Boolean).length
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to fetch media files' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const filename = searchParams.get('file')
    
    if (!filename) {
      return NextResponse.json(
        { error: 'Filename is required' },
        { status: 400 }
      )
    }
    
    const filePath = path.join(MEDIA_PATH, filename)
    
    // Security check - prevent directory traversal
    if (!filePath.startsWith(MEDIA_PATH)) {
      return NextResponse.json(
        { error: 'Invalid file path' },
        { status: 400 }
      )
    }
    
    await fs.unlink(filePath)
    
    // Delete thumbnail if exists
    const ext = path.extname(filename)
    const thumbnailName = `${path.basename(filename, ext)}_thumb.jpg`
    const thumbnailPath = path.join(THUMBNAILS_PATH, thumbnailName)
    
    try {
      await fs.unlink(thumbnailPath)
    } catch {
      // Thumbnail might not exist
    }
    
    return NextResponse.json({ success: true })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to delete media file' },
      { status: 500 }
    )
  }
}