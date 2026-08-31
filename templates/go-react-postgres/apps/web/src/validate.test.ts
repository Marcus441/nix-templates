import { expect, it } from "vitest";
import { normalizeName } from "./validate";

it("trims a name and rejects a blank one", () => {
  expect(normalizeName("  smoke  ")).toBe("smoke");
  expect(normalizeName("   ")).toBeNull();
});
