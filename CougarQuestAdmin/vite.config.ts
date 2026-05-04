import path from 'path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: { port: 1984, strictPort: true, host: 'localhost' },
  preview: { port: 1984, strictPort: true },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
