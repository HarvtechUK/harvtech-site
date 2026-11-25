import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://harvtech.co.uk',
  integrations: [sitemap()],
  // The Docs and Writing sections were replaced by News. Old links land there.
  redirects: {
    '/docs': '/news',
    '/writing': '/news',
  },
  vite: {
    plugins: [tailwindcss()],
  },
});
