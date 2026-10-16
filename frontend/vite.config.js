import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// In dev, /api, /health, /ready and /metrics are proxied to the backend so the
// browser code can use relative URLs exactly as it does behind nginx in prod.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:8100",
      "/health": "http://localhost:8100",
      "/ready": "http://localhost:8100",
      "/metrics": "http://localhost:8100",
    },
  },
  build: { outDir: "dist", sourcemap: false },
});
