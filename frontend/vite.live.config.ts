import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import tailwindcss from '@tailwindcss/vite';

const liveApi = 'https://status-lanis-mobile.alessioc42.dev';

/** Local Vue app, `/api` proxied to the hosted statusmonitor. */
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    open: true,
    proxy: {
      '/api': {
        target: liveApi,
        changeOrigin: true,
        secure: true,
      },
    },
  },
});
