import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./styles/composer.css";

const rootElement = document.getElementById("root");

if (!rootElement) {
  throw new Error("Inputo composer root element is missing.");
}

createRoot(rootElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
