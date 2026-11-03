import {StrictMode} from "react";
import {createRoot} from "react-dom/client";
import {App} from "./App";
import "./index.css";

const root = document.getElementById("root");
if (root === null) {
  throw new Error("#root가 없습니다");
}
createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
