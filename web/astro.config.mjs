 import { defineConfig } from "astro/config";
 import tailwindcss from "@tailwindcss/vite";

 export default defineConfig({
   site: "https://gallup-scores.vercel.app/",
   vite: {
     plugins: [tailwindcss()],
   },
 });