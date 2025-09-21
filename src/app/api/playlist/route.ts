import { NextRequest, NextResponse } from 'next/server'
import fs from 'fs/promises'
import path from 'path'

const PLAYLISTS_PATH = process.env.PLAYLISTS_PATH || '/opt/pisignage/playlists'
const MEDIA_PATH = process.env.MEDIA_PATH || '/opt/pisignage/media'

// Ensure directories exist
async function ensureDirectories() {
  await fs.mkdir(PLAYLISTS_PATH, { recursive: true })
  await fs.mkdir(MEDIA_PATH, { recursive: true })
}

export async function GET(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')
    
    if (id) {
      // Get specific playlist
      const playlistPath = path.join(PLAYLISTS_PATH, `${id}.json`)
      const content = await fs.readFile(playlistPath, 'utf-8')
      return NextResponse.json(JSON.parse(content))
    }
    
    // Get all playlists
    const files = await fs.readdir(PLAYLISTS_PATH)
    const playlists = await Promise.all(
      files
        .filter(file => file.endsWith('.json'))
        .map(async file => {
          const content = await fs.readFile(path.join(PLAYLISTS_PATH, file), 'utf-8')
          return {
            id: file.replace('.json', ''),
            ...JSON.parse(content)
          }
        })
    )
    
    return NextResponse.json({ playlists })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to fetch playlists' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const data = await request.json()
    const { name, items = [], settings = {} } = data
    
    if (!name) {
      return NextResponse.json(
        { error: 'Playlist name is required' },
        { status: 400 }
      )
    }
    
    const id = `playlist_${Date.now()}`
    const playlist = {
      name,
      items,
      settings: {
        loop: true,
        shuffle: false,
        transition: 'fade',
        ...settings
      },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
    
    await fs.writeFile(
      path.join(PLAYLISTS_PATH, `${id}.json`),
      JSON.stringify(playlist, null, 2)
    )
    
    return NextResponse.json({ id, ...playlist })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to create playlist' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')
    
    if (!id) {
      return NextResponse.json(
        { error: 'Playlist ID is required' },
        { status: 400 }
      )
    }
    
    const data = await request.json()
    const playlistPath = path.join(PLAYLISTS_PATH, `${id}.json`)
    
    // Check if playlist exists
    try {
      await fs.access(playlistPath)
    } catch {
      return NextResponse.json(
        { error: 'Playlist not found' },
        { status: 404 }
      )
    }
    
    const existingContent = await fs.readFile(playlistPath, 'utf-8')
    const existingPlaylist = JSON.parse(existingContent)
    
    const updatedPlaylist = {
      ...existingPlaylist,
      ...data,
      updatedAt: new Date().toISOString()
    }
    
    await fs.writeFile(
      playlistPath,
      JSON.stringify(updatedPlaylist, null, 2)
    )
    
    return NextResponse.json({ id, ...updatedPlaylist })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to update playlist' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')
    
    if (!id) {
      return NextResponse.json(
        { error: 'Playlist ID is required' },
        { status: 400 }
      )
    }
    
    const playlistPath = path.join(PLAYLISTS_PATH, `${id}.json`)
    await fs.unlink(playlistPath)
    
    return NextResponse.json({ success: true })
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to delete playlist' },
      { status: 500 }
    )
  }
}