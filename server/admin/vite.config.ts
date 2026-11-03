import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import {defineConfig} from "vite";

// 개발 서버는 5173 포트다. 에뮬레이터(server/firebase.json)의 포트와 겹치지 않는다.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {port: 5173, strictPort: true},
});
