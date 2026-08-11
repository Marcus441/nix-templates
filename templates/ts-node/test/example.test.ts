import { describe, it, expect } from "vitest";
import { greet } from "../src/index";

describe("greet function", () => {
  it("should return greeting message", () => {
    expect(greet("Marcus")).toBe("Hello, Marcus!");
  });

  it("should handle empty string", () => {
    expect(greet("")).toBe("Hello, !");
  });
});
