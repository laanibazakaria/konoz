import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // Chemins relatifs : le panneau fonctionne aussi bien à la racine qu'en sous-dossier (/konoz/admin/).
  base: './',
});
