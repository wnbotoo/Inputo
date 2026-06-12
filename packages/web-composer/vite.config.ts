import { resolve } from "node:path";
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  base: "./",
  plugins: [react(), classicWKWebViewAssetTags()],
  build: {
    modulePreload: {
      polyfill: false
    },
    outDir: resolve(__dirname, "../../apps/macos/InputoModules/Sources/InputoComposerFeature/Resources/WebComposer"),
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

function classicWKWebViewAssetTags(): Plugin {
  return {
    name: "inputo-classic-wkwebview-asset-tags",
    enforce: "post",
    transformIndexHtml(html, context) {
      if (!context.bundle) {
        return html;
      }
      return html
        .replace(
          '<script type="module" crossorigin src="./composer.js"></script>',
          '<script defer src="./composer.js"></script>'
        )
        .replace(
          '<link rel="stylesheet" crossorigin href="./composer.css">',
          '<link rel="stylesheet" href="./composer.css">'
        );
    }
  };
}
