import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    // React Testing Library needs DOM globals like window/document
    environment: "jsdom",

    // Make test discovery explicit and stable
    include: ["src/**/*.{test,spec}.{js,jsx}"],

    // Optional but helpful in CI: clearer output
    reporters: ["default"]
  }
});