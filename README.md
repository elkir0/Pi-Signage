# 🚀 PiSignage 2.0 - Modern Digital Signage System

<div align="center">

![Next.js](https://img.shields.io/badge/Next.js-14.2-black?style=for-the-badge&logo=next.js)
![React](https://img.shields.io/badge/React-18.3-61DAFB?style=for-the-badge&logo=react)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-3178C6?style=for-the-badge&logo=typescript)
![Tailwind CSS](https://img.shields.io/badge/Tailwind-3.4-06B6D4?style=for-the-badge&logo=tailwindcss)

**Next-generation digital signage system built with modern web technologies**

[Features](#-features) • [Installation](#-installation) • [Documentation](#-documentation) • [API](#-api-reference) • [Contributing](#-contributing)

</div>

---

## 🎯 Overview

PiSignage 2.0 is a complete rewrite of the original PiSignage system, built from the ground up with modern web technologies. This new version leverages Next.js, React, and TypeScript to provide a robust, scalable, and maintainable digital signage solution optimized for Raspberry Pi and other platforms.

## ✨ Features

### Core Technologies
- **Next.js 14** - Server-side rendering and API routes
- **React 18** - Modern component architecture
- **TypeScript** - Type safety and better DX
- **Tailwind CSS** - Utility-first styling
- **Radix UI** - Accessible component primitives
- **React Query** - Server state management
- **Zustand** - Client state management
- **Socket.io** - Real-time updates
- **Chart.js** - Data visualization

### Functionality
- 📊 **Real-time Dashboard** - System monitoring with live charts
- 📝 **Playlist Management** - Drag-and-drop playlist editor
- 📁 **Media Library** - Upload and manage media files
- 🎬 **YouTube Integration** - Direct YouTube video downloads
- 📅 **Scheduling System** - Advanced scheduling with cron-like syntax
- 📈 **Analytics** - Playback statistics and reports
- 🎨 **Theme Support** - Light/dark mode with system preference
- 📱 **Responsive Design** - Works on all devices
- 🔄 **Auto-updates** - OTA updates support
- 🌐 **Multi-language** - i18n ready

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ 
- npm or yarn
- Raspberry Pi OS Bookworm Lite (64-bit) or any Linux system
- 2GB+ RAM recommended

### Installation

```bash
# Clone the repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local

# Run development server
npm run dev
```

Access the application at `http://localhost:3000`

### Production Deployment

```bash
# Build for production
npm run build

# Start production server
npm run start

# Or use PM2 for process management
npm install -g pm2
pm2 start npm --name "pisignage" -- start
pm2 save
pm2 startup
```

## 📦 Project Structure

```
pisignage/
├── src/
│   ├── app/                 # Next.js app directory
│   │   ├── api/             # API routes
│   │   ├── layout.tsx       # Root layout
│   │   └── page.tsx         # Main dashboard
│   ├── components/          # React components
│   │   ├── ui/             # Base UI components
│   │   ├── dashboard/      # Dashboard components
│   │   ├── playlist/       # Playlist components
│   │   ├── media/          # Media components
│   │   └── ...
│   ├── hooks/              # Custom React hooks
│   ├── lib/                # Utility functions
│   ├── services/           # API services
│   ├── stores/             # Zustand stores
│   ├── types/              # TypeScript types
│   └── utils/              # Helper functions
├── public/                 # Static assets
├── scripts/                # System scripts
├── docs/                   # Documentation
└── tests/                  # Test files
```

## �� Configuration

### Environment Variables

Create a `.env.local` file:

```env
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_WS_URL=ws://localhost:3000

# Media Storage
MEDIA_PATH=/opt/pisignage/media
PLAYLISTS_PATH=/opt/pisignage/playlists
THUMBNAILS_PATH=/opt/pisignage/public/thumbnails

# VLC Configuration
VLC_HTTP_PORT=8080
VLC_HTTP_PASSWORD=vlc

# System
NODE_ENV=production
```

### System Configuration

For Raspberry Pi deployment:

```bash
# Install system dependencies
sudo apt-get update
sudo apt-get install -y \
  vlc \
  ffmpeg \
  nginx \
  nodejs \
  npm

# Configure VLC
echo "http 0 8080" | sudo tee /etc/vlc/vlcrc

# Set up systemd service
sudo cp scripts/pisignage.service /etc/systemd/system/
sudo systemctl enable pisignage
sudo systemctl start pisignage
```

## 📡 API Reference

### System API

```typescript
GET /api/system
// Returns system information (CPU, memory, disk, temperature)

GET /api/system/vlc
// Returns VLC player status
```

### Playlist API

```typescript
GET /api/playlist
// Get all playlists

POST /api/playlist
// Create new playlist

PUT /api/playlist?id={id}
// Update playlist

DELETE /api/playlist?id={id}
// Delete playlist
```

### Media API

```typescript
GET /api/media
// List all media files

POST /api/media/upload
// Upload media file

DELETE /api/media?file={filename}
// Delete media file
```

### YouTube API

```typescript
POST /api/youtube/download
// Download YouTube video
{
  "url": "https://youtube.com/watch?v=...",
  "quality": "720p"
}
```

## 🎨 UI Components

The system uses a modern component library built on Radix UI:

- **Tabs** - Main navigation
- **Cards** - Content containers
- **Buttons** - Actions
- **Dialogs** - Modals
- **Forms** - Input handling
- **Tables** - Data display
- **Charts** - Visualizations
- **Toast** - Notifications
- **Dropzone** - File uploads

## 🧪 Testing

```bash
# Run unit tests
npm run test

# Run integration tests
npm run test:integration

# Run E2E tests
npm run test:e2e

# Coverage report
npm run test:coverage
```

## 📚 Documentation

- [Installation Guide](docs/installation.md)
- [User Manual](docs/user-manual.md)
- [API Documentation](docs/api.md)
- [Development Guide](docs/development.md)
- [Deployment Guide](docs/deployment.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Next.js Team** - For the amazing framework
- **Vercel** - For hosting and deployment tools
- **Radix UI** - For accessible components
- **Raspberry Pi Foundation** - For the hardware platform
- **Open Source Community** - For all the amazing tools

## 🚧 Roadmap

- [ ] Mobile app for remote control
- [ ] Cloud sync support
- [ ] Multi-display support
- [ ] Advanced analytics dashboard
- [ ] Plugin system
- [ ] WebRTC streaming
- [ ] AI content recommendations
- [ ] Blockchain integration for content verification

## 📞 Support

- **GitHub Issues**: [Report bugs](https://github.com/elkir0/Pi-Signage/issues)
- **Discussions**: [Ask questions](https://github.com/elkir0/Pi-Signage/discussions)
- **Email**: support@pisignage.com

---

<div align="center">

**Built with ❤️ using modern web technologies**

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>

</div>