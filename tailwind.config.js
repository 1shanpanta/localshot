/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/renderer/src/**/*.{ts,tsx,html}'],
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#1a1a2e',
          light: '#25253e',
          lighter: '#2d2d4a'
        },
        accent: {
          red: '#ff3b3b',
          blue: '#4a9eff',
          green: '#34d399',
          yellow: '#fbbf24',
          purple: '#a78bfa'
        }
      }
    }
  },
  plugins: []
}
