import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import App from "./App.jsx";

describe("App", () => {
  it("renders without crashing", () => {
    render(<App />);
    // Minimal assertion: App renders *something*.
    // If you have a stable title/button/text, replace this with a more specific check.
    expect(screen.getByRole("button")).toBeTruthy();
  });
});