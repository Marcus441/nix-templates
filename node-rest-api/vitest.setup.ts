// vite.config.ts or vitest.config.ts
/// <reference types="vitest" />
import { defineConfig } from "vite";

export default defineConfig({
  test: {
    environment: "node",

    // Optional: Configure test file patterns
    include: ["**/*.test.ts", "**/*.test.js"],
    exclude: ["node_modules", "dist", ".idea", ".git", ".cache"],

    // Optional: Configure coverage reporting
    coverage: {
      provider: "v8", // or 'istanbul'
      reporter: ["text", "json", "html"],
      include: ["src/**/*.ts"],
      exclude: ["src/types.ts"],
    },

    // Optional: Improve performance by disabling isolation if tests are well-behaved
    isolate: false,

    // Optional: Disable parallelism for faster startup if needed
    fileParallelism: true,

    testTimeout: 5000,
    setupFiles: ["./vitest.setup.ts"],
  },
  server: {
    port: 3001,
  },
});
