/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'standalone',
  
  // Configuration pour Raspberry Pi
  experimental: {
    serverActions: {
      bodySizeLimit: '500mb',
    },
  },
  
  // API Configuration
  async rewrites() {
    return [
      {
        source: '/api/vlc/:path*',
        destination: 'http://localhost:8080/:path*', // VLC HTTP interface
      },
    ];
  },
  
  // Headers for security
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
        ],
      },
    ];
  },
  
  images: {
    domains: ['localhost', '192.168.1.103'],
    unoptimized: true, // Pour Raspberry Pi
  },
};

module.exports = nextConfig;