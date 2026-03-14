import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default [
  {
    files: ["**/*.{js,jsx}"],
    ignores: ["dist/**", "node_modules/**"],

    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      parserOptions: {
        ecmaFeatures: {
          jsx: true
        }
      }
    },

    plugins: {
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh
    },

    rules: {
      // Enforce the Rules of Hooks
      ...reactHooks.configs.recommended.rules,

      // If you use React Refresh (Vite dev), ensure exports are compatible
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }]
    }
  }
];