import { describe, it, expect } from "vitest";
import { createHmac } from "node:crypto";
import { verifySignature } from "../src/verify";

const secret = "topsecret";
function sign(body: string): string {
  return "sha256=" + createHmac("sha256", secret).update(body).digest("hex");
}

describe("verifySignature", () => {
  const body = JSON.stringify({ action: "opened" });

  it("accepts a correct signature", () => {
    expect(verifySignature(body, sign(body), secret)).toBe(true);
  });

  it("rejects a wrong signature", () => {
    expect(verifySignature(body, sign("tampered"), secret)).toBe(false);
  });

  it("rejects a missing header", () => {
    expect(verifySignature(body, undefined, secret)).toBe(false);
  });

  it("rejects a malformed header", () => {
    expect(verifySignature(body, "garbage", secret)).toBe(false);
  });
});
