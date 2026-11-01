// 버그를 잡는 규칙만 둔다. 공백, 따옴표 같은 스타일은 Prettier가 맞춘다.
import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: ["lib/**", "generated/**", "eslint.config.mjs"],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      globals: globals.node,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // await 없이 버린 Promise. Functions가 먼저 끝나 DB 쓰기가 잘리는 버그를 막는다.
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-misused-promises": "error",
      "@typescript-eslint/no-unused-vars": ["error", {argsIgnorePattern: "^_"}],
    },
  },
  prettier,
);
