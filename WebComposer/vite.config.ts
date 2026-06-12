import { resolve } from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  base: "./",
  plugins: [react()],
  build: {
    modulePreload: {
      polyfill: false
    },
    outDir: resolve(__dirname, "../InputoModules/Sources/InputoComposerFeature/Resources/WebComposer"),
    emptyOutDir: true,
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        entryFileNames: "composer.js",
        chunkFileNames: "composer.js",
        assetFileNames: (assetInfo) => {
          const name = assetInfo.names?.[0] ?? assetInfo.name ?? "";
          return name.endsWith(".css") ? "composer.css" : "assets/[name][extname]";
        }
      }
    }
  }
});
