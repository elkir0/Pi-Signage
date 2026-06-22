// @ts-check
import { defineConfig } from 'astro/config';

// Zaforge vitrine — STATIC build. Output is a plain dist/ directory served by
// nginx on VM600 (vhost zaforge.com on CT101). No SSR, no adapter, no runtime.
export default defineConfig({
  site: 'https://zaforge.com',
  output: 'static',
  trailingSlash: 'ignore',
  build: {
    // Inline tiny stylesheets to cut requests on first paint.
    inlineStylesheets: 'auto',
    assets: 'assets',
  },
  compressHTML: true,
  devToolbar: { enabled: false },
});
