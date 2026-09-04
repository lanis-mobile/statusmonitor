import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import tailwindcss from '@tailwindcss/vite';

/** Dev-only config: local frontend against the live statusmonitor API. */
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.API_PROXY ?? 'http://127.0.0.1:8080',
        changeOrigin: true,
        secure: true,
      },
    },
  },
});
