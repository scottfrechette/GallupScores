 import { defineConfig } from "astro/config";
 import tailwindcss from "@tailwindcss/vite";

 export default defineConfig({
   site: "https://gallup-scores.scottfrechette.com",
   vite: {
     plugins: [tailwindcss()],
   },
 });