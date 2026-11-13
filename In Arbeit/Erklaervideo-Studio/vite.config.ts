import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Oberfläche läuft auf 5173, der lokale Server (Claude, Stimme, Rendern) auf 4710.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
    proxy: { "/api": "http://localhost:4710" },
  },
});
