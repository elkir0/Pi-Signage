import { NextRequest, NextResponse } from 'next/server'
import fs from 'fs/promises'
import path from 'path'
import { writeFile } from 'fs/promises'

interface UploadProgress {
  id: string
  filename: string
  size: number
  uploaded: number
  status: 'uploading' | 'completed' | 'error'
  error?: string
  startTime: string
  endTime?: string
  chunks?: number
  currentChunk?: number
}

interface UploadResponse {
  success: boolean
  data?: {
    uploadId: string
    filename: string
    size: number
    message: string
  }
  error?: string
}

const MEDIA_DIR = '/opt/pisignage/media'
const UPLOAD_PROGRESS_DIR = '/opt/pisignage/src/data/upload-progress'
const CHUNK_SIZE = 1024 * 1024 // 1MB chunks
const MAX_FILE_SIZE = 500 * 1024 * 1024 // 500MB limit

// Allowed MIME types for security
const ALLOWED_MIME_TYPES = [
  // Video formats
  'video/mp4',
  'video/avi',
  'video/mkv',
  'video/mov',
  'video/wmv',
  'video/flv',
  'video/webm',
  'video/3gp',
  'video/m4v',
  // Image formats
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/bmp',
  'image/webp',
  'image/tiff',
  // Audio formats
  'audio/mp3',
  'audio/wav',
  'audio/ogg',
  'audio/m4a',
  'audio/flac'
]

// File extensions mapping
const ALLOWED_EXTENSIONS = [
  '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.3gp', '.m4v',
  '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff',
  '.mp3', '.wav', '.ogg', '.m4a', '.flac'
]

function generateUploadId(): string {
  return `up_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

function sanitizeFilename(filename: string): string {
  // Remove or replace dangerous characters
  return filename
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_{2,}/g, '_')
    .replace(/^_+|_+$/g, '')
}

function isAllowedFileType(filename: string, mimeType?: string): boolean {
  const ext = path.extname(filename).toLowerCase()
  const isExtensionAllowed = ALLOWED_EXTENSIONS.includes(ext)
  const isMimeTypeAllowed = !mimeType || ALLOWED_MIME_TYPES.includes(mimeType)
  
  return isExtensionAllowed && isMimeTypeAllowed
}

async function ensureDirectories() {
  await fs.mkdir(MEDIA_DIR, { recursive: true })
  await fs.mkdir(UPLOAD_PROGRESS_DIR, { recursive: true })
}

async function saveUploadProgress(progress: UploadProgress) {
  const progressFile = path.join(UPLOAD_PROGRESS_DIR, `${progress.id}.json`)
  await fs.writeFile(progressFile, JSON.stringify(progress, null, 2))
}

async function loadUploadProgress(uploadId: string): Promise<UploadProgress | null> {
  try {
    const progressFile = path.join(UPLOAD_PROGRESS_DIR, `${uploadId}.json`)
    const data = await fs.readFile(progressFile, 'utf-8')
    return JSON.parse(data)
  } catch {
    return null
  }
}

async function getAllUploadProgress(): Promise<UploadProgress[]> {
  try {
    const files = await fs.readdir(UPLOAD_PROGRESS_DIR)
    const progressFiles = files.filter(f => f.endsWith('.json'))
    
    const progressList = await Promise.all(
      progressFiles.map(async (file) => {
        try {
          const data = await fs.readFile(path.join(UPLOAD_PROGRESS_DIR, file), 'utf-8')
          return JSON.parse(data)
        } catch {
          return null
        }
      })
    )
    
    return progressList.filter(p => p !== null)
  } catch {
    return []
  }
}

export async function POST(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const formData = await request.formData()
    const file = formData.get('file') as File
    const chunkIndex = formData.get('chunkIndex') as string
    const totalChunks = formData.get('totalChunks') as string
    const uploadId = formData.get('uploadId') as string
    
    if (!file) {
      return NextResponse.json(
        { success: false, error: 'No file provided' },
        { status: 400 }
      )
    }
    
    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { success: false, error: `File size exceeds ${MAX_FILE_SIZE / (1024 * 1024)}MB limit` },
        { status: 400 }
      )
    }
    
    // Validate file type
    if (!isAllowedFileType(file.name, file.type)) {
      return NextResponse.json(
        { success: false, error: 'File type not allowed' },
        { status: 400 }
      )
    }
    
    const sanitizedFilename = sanitizeFilename(file.name)
    const finalFilePath = path.join(MEDIA_DIR, sanitizedFilename)
    
    // Check if file already exists
    try {
      await fs.access(finalFilePath)
      return NextResponse.json(
        { success: false, error: 'File already exists' },
        { status: 409 }
      )
    } catch {
      // File doesn't exist, which is good
    }
    
    // Handle chunked upload
    if (chunkIndex && totalChunks && uploadId) {
      const currentUploadId = uploadId
      const currentChunk = parseInt(chunkIndex)
      const totalChunksNum = parseInt(totalChunks)
      
      if (isNaN(currentChunk) || isNaN(totalChunksNum)) {
        return NextResponse.json(
          { success: false, error: 'Invalid chunk parameters' },
          { status: 400 }
        )
      }
      
      // Load or create upload progress
      let progress = await loadUploadProgress(currentUploadId)
      if (!progress) {
        progress = {
          id: currentUploadId,
          filename: sanitizedFilename,
          size: file.size,
          uploaded: 0,
          status: 'uploading',
          startTime: new Date().toISOString(),
          chunks: totalChunksNum,
          currentChunk: 0
        }
      }
      
      // Create temporary chunk file
      const chunkDir = path.join(UPLOAD_PROGRESS_DIR, `chunks_${currentUploadId}`)
      await fs.mkdir(chunkDir, { recursive: true })
      
      const chunkPath = path.join(chunkDir, `chunk_${currentChunk}`)
      const bytes = await file.arrayBuffer()
      await writeFile(chunkPath, Buffer.from(bytes))
      
      // Update progress
      progress.currentChunk = currentChunk + 1
      progress.uploaded += bytes.byteLength
      await saveUploadProgress(progress)
      
      // Check if all chunks are uploaded
      if (currentChunk + 1 === totalChunksNum) {
        // Reassemble file
        try {
          const finalFile = await fs.open(finalFilePath, 'w')
          
          for (let i = 0; i < totalChunksNum; i++) {
            const chunkPath = path.join(chunkDir, `chunk_${i}`)
            const chunkData = await fs.readFile(chunkPath)
            await finalFile.write(chunkData)
          }
          
          await finalFile.close()
          
          // Clean up chunks
          await fs.rm(chunkDir, { recursive: true, force: true })
          
          // Update progress
          progress.status = 'completed'
          progress.endTime = new Date().toISOString()
          await saveUploadProgress(progress)
          
          return NextResponse.json({
            success: true,
            data: {
              uploadId: currentUploadId,
              filename: sanitizedFilename,
              size: file.size,
              message: 'File uploaded successfully'
            }
          })
          
        } catch (error) {
          // Clean up on error
          await fs.rm(chunkDir, { recursive: true, force: true })
          await fs.unlink(finalFilePath).catch(() => {})
          
          progress.status = 'error'
          progress.error = error instanceof Error ? error.message : 'Assembly failed'
          progress.endTime = new Date().toISOString()
          await saveUploadProgress(progress)
          
          throw error
        }
      }
      
      // Return chunk upload success
      return NextResponse.json({
        success: true,
        data: {
          uploadId: currentUploadId,
          chunkIndex: currentChunk,
          uploaded: progress.uploaded,
          total: progress.size,
          message: `Chunk ${currentChunk + 1}/${totalChunksNum} uploaded`
        }
      })
      
    } else {
      // Handle single file upload (non-chunked)
      const newUploadId = generateUploadId()
      
      const progress: UploadProgress = {
        id: newUploadId,
        filename: sanitizedFilename,
        size: file.size,
        uploaded: 0,
        status: 'uploading',
        startTime: new Date().toISOString()
      }
      
      await saveUploadProgress(progress)
      
      try {
        const bytes = await file.arrayBuffer()
        await writeFile(finalFilePath, Buffer.from(bytes))
        
        progress.uploaded = file.size
        progress.status = 'completed'
        progress.endTime = new Date().toISOString()
        await saveUploadProgress(progress)
        
        return NextResponse.json({
          success: true,
          data: {
            uploadId: newUploadId,
            filename: sanitizedFilename,
            size: file.size,
            message: 'File uploaded successfully'
          }
        })
        
      } catch (error) {
        await fs.unlink(finalFilePath).catch(() => {})
        
        progress.status = 'error'
        progress.error = error instanceof Error ? error.message : 'Upload failed'
        progress.endTime = new Date().toISOString()
        await saveUploadProgress(progress)
        
        throw error
      }
    }
    
  } catch (error) {
    console.error('Upload API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Upload failed' 
      },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    await ensureDirectories()
    
    const searchParams = request.nextUrl.searchParams
    const uploadId = searchParams.get('id')
    
    if (uploadId) {
      // Get specific upload progress
      const progress = await loadUploadProgress(uploadId)
      if (!progress) {
        return NextResponse.json(
          { success: false, error: 'Upload not found' },
          { status: 404 }
        )
      }
      
      return NextResponse.json({
        success: true,
        data: progress
      })
    } else {
      // Get all uploads
      const allProgress = await getAllUploadProgress()
      
      return NextResponse.json({
        success: true,
        data: allProgress.sort((a, b) => 
          new Date(b.startTime).getTime() - new Date(a.startTime).getTime()
        )
      })
    }
    
  } catch (error) {
    console.error('Upload status API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to get upload status' 
      },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const uploadId = searchParams.get('id')
    
    if (!uploadId) {
      return NextResponse.json(
        { success: false, error: 'Upload ID is required' },
        { status: 400 }
      )
    }
    
    // Remove progress file
    const progressFile = path.join(UPLOAD_PROGRESS_DIR, `${uploadId}.json`)
    try {
      await fs.unlink(progressFile)
    } catch {
      // File might not exist
    }
    
    // Clean up any remaining chunks
    const chunkDir = path.join(UPLOAD_PROGRESS_DIR, `chunks_${uploadId}`)
    try {
      await fs.rm(chunkDir, { recursive: true, force: true })
    } catch {
      // Directory might not exist
    }
    
    return NextResponse.json({
      success: true,
      message: 'Upload record deleted'
    })
    
  } catch (error) {
    console.error('Upload delete API error:', error)
    return NextResponse.json(
      { 
        success: false, 
        error: error instanceof Error ? error.message : 'Failed to delete upload record' 
      },
      { status: 500 }
    )
  }
}