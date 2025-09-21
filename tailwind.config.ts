import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: ['class'],
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Premium Color Palette
        'midnight': '#0A0A0F',
        'obsidian': '#12121A',
        'charcoal': '#1A1A24',
        'slate': '#2A2A38',
        'steel': '#3A3A4C',
        'zinc': '#4A4A60',
        'crimson': '#DC2626',
        'ruby': '#FF4444',
        'coral': '#FF6B6B',
        'amber': '#FFA500',
        'emerald': '#10B981',
        'sapphire': '#3B82F6',
        
        // Legacy compatibility
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        
        // PiSignage Spectacular Design System
        'ps-black': 'hsl(var(--ps-black))',
        'ps-midnight': 'hsl(var(--ps-midnight))',
        'ps-obsidian': 'hsl(var(--ps-obsidian))',
        'ps-charcoal': 'hsl(var(--ps-charcoal))',
        'ps-crimson': 'hsl(var(--ps-crimson))',
        'ps-ruby': 'hsl(var(--ps-ruby))',
        'ps-coral': 'hsl(var(--ps-coral))',
        'ps-amber': 'hsl(var(--ps-amber))',
        'ps-slate': 'hsl(var(--ps-slate))',
        'ps-steel': 'hsl(var(--ps-steel))',
        'ps-zinc': 'hsl(var(--ps-zinc))',
        'ps-smoke': 'hsl(var(--ps-smoke))',
        'ps-success': 'hsl(var(--ps-success))',
        'ps-warning': 'hsl(var(--ps-warning))',
        'ps-error': 'hsl(var(--ps-error))',
        'ps-info': 'hsl(var(--ps-info))',
      },
      borderRadius: {
        'xs': 'var(--ps-radius-xs)',
        'sm': 'var(--ps-radius-sm)',
        'md': 'var(--ps-radius-md)',
        'lg': 'var(--ps-radius-lg)',
        'xl': 'var(--ps-radius-xl)',
        '2xl': 'var(--ps-radius-2xl)',
      },
      spacing: {
        'xs': 'var(--ps-space-xs)',
        'sm': 'var(--ps-space-sm)',
        'md': 'var(--ps-space-md)',
        'lg': 'var(--ps-space-lg)',
        'xl': 'var(--ps-space-xl)',
        '2xl': 'var(--ps-space-2xl)',
        '3xl': 'var(--ps-space-3xl)',
      },
      fontFamily: {
        'sans': ['Inter', 'system-ui', 'sans-serif'],
        'mono': ['JetBrains Mono', 'Menlo', 'Monaco', 'monospace'],
      },
      boxShadow: {
        'ps-sm': 'var(--ps-shadow-sm)',
        'ps-md': 'var(--ps-shadow-md)',
        'ps-lg': 'var(--ps-shadow-lg)',
        'ps-xl': 'var(--ps-shadow-xl)',
        'ps-glass': 'var(--ps-glass-shadow)',
      },
      backdropBlur: {
        'xs': '2px',
        'sm': '4px',
        'md': '8px',
        'lg': '16px',
        'xl': '24px',
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        "shimmer": {
          "0%": { backgroundPosition: "-1000px 0" },
          "100%": { backgroundPosition: "1000px 0" },
        },
        "pulse-glow": {
          "0%, 100%": { boxShadow: "0 0 20px rgba(220, 38, 38, 0.5)" },
          "50%": { boxShadow: "0 0 40px rgba(220, 38, 38, 0.8)" },
        },
        "float": {
          "0%, 100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-10px)" },
        },
        "gradient-shift": {
          "0%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
          "100%": { backgroundPosition: "0% 50%" },
        },
        "slide-up": {
          from: { opacity: "0", transform: "translateY(20px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        "rotate-3d": {
          "0%": { transform: "perspective(1000px) rotateY(0)" },
          "100%": { transform: "perspective(1000px) rotateY(360deg)" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        "shimmer": "shimmer 3s infinite linear",
        "pulse-glow": "pulse-glow 2s infinite",
        "float": "float 3s ease-in-out infinite",
        "gradient": "gradient-shift 4s ease infinite",
        "slide-up": "slide-up 0.5s ease-out",
        "rotate-3d": "rotate-3d 20s linear infinite",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}

export default config