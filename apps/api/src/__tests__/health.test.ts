import { describe, it, expect } from "vitest";
import { createApp } from "../app.js";

describe("GET /v1/health", () => {
  const app = createApp();

  it("returns 200 with status ok", async () => {
    const res = await app.request("/v1/health");
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe("ok");
    expect(body.timestamp).toBeDefined();
  });
});
