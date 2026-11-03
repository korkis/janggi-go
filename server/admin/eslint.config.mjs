// 버그를 잡는 규칙만 둔다. 공백, 따옴표 같은 스타일은 Prettier가 맞춘다(docs/dev_rules.md의 정적 검사).
import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: ["dist/**", "eslint.config.mjs"],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {"react-hooks": reactHooks},
    rules: {
      // Hook 호출 순서와 의존성 배열의 빠진 값. 화면이 오래된 값을 쓰는 버그를 막는다.
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "error",
      // await 없이 버린 Promise. 조치 실패가 화면에 드러나지 않는 버그를 막는다.
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-misused-promises": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": ["error", {argsIgnorePattern: "^_"}],
    },
  },
  prettier,
);
