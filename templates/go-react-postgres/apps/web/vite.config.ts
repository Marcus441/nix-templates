import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// The dev server proxies API routes to the api process devenv supervises, so
// the app can fetch("/items") with no CORS setup. infra/docker/nginx.conf does
// the same job in the composed deployment.
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/health": "http://127.0.0.1:5080",
      "/items": "http://127.0.0.1:5080",
    },
  },
});
