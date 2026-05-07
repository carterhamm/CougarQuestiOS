import path from 'path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // Served at cougarquest.com/admin in production. The base controls how
  // Vite emits asset URLs in index.html — without it the bundled JS/CSS
  // would 404 because they'd be requested from the camper app's root.
  base: '/admin/',
  server: { port: 1984, strictPort: true, host: 'localhost' },
  preview: { port: 1984, strictPort: true },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
