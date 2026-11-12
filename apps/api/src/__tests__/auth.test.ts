import { describe, it, expect, vi, beforeEach } from "vitest";
import { createApp } from "../app.js";
import { signAccessToken } from "../services/jwt.js";
import { getDb } from "../db.js";
import { users, refreshTokens } from "@boored/db";
import { eq } from "drizzle-orm";
import * as jwtService from "../services/jwt.js";

describe("Auth Routes (/v1/auth/* & /v1/me)", () => {
  const app = createApp();
  const db = getDb();

  beforeEach(async () => {
    vi.restoreAllMocks();
  });

  it("POST /v1/auth/google verifies token, creates user and returns tokens", async () => {
    vi.spyOn(jwtService, "verifyGoogleIdToken").mockResolvedValueOnce({
      sub: "google-test-sub-12345",
      email: "testuser@example.com",
      name: "Test Student",
      picture: "https://example.com/avatar.jpg",
    });

    const res = await app.request("/v1/auth/google", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id_token: "mock-valid-google-id-token" }),
    });

    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.access_token).toBeDefined();
    expect(data.refresh_token).toBeDefined();
    expect(data.user.email).toBe("testuser@example.com");
    expect(data.user.name).toBe("Test Student");

    // Clean up or check user exists in DB
    const [user] = await db
      .select()
      .from(users)
      .where(eq(users.google_sub, "google-test-sub-12345"));
    expect(user).toBeDefined();
  });

  it("GET /v1/me rejects unauthenticated request with 401", async () => {
    const res = await app.request("/v1/me");
    expect(res.status).toBe(401);
  });

  it("GET /v1/me returns user profile with valid Bearer token", async () => {
    // 1. Authenticate user to get tokens
    vi.spyOn(jwtService, "verifyGoogleIdToken").mockResolvedValueOnce({
      sub: "google-test-sub-me-test",
      email: "metest@example.com",
      name: "Me Tester",
      picture: undefined,
    });

    const authRes = await app.request("/v1/auth/google", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id_token: "mock-token-me" }),
    });
    const authData = await authRes.json();

    // 2. Request /me
    const meRes = await app.request("/v1/me", {
      headers: {
        Authorization: `Bearer ${authData.access_token}`,
      },
    });

    expect(meRes.status).toBe(200);
    const meData = await meRes.json();
    expect(meData.email).toBe("metest@example.com");
    expect(meData.name).toBe("Me Tester");
    expect(meData.id).toBe(authData.user.id);
  });

  it("POST /v1/auth/refresh rotates token and detects reuse", async () => {
    vi.spyOn(jwtService, "verifyGoogleIdToken").mockResolvedValueOnce({
      sub: "google-test-sub-refresh",
      email: "refreshtest@example.com",
      name: "Refresh Tester",
    });

    const authRes = await app.request("/v1/auth/google", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id_token: "mock-token-refresh" }),
    });
    const { refresh_token: initialRefreshToken } = await authRes.json();

    // 1. Rotate token
    const refreshRes = await app.request("/v1/auth/refresh", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: initialRefreshToken }),
    });
    expect(refreshRes.status).toBe(200);
    const refreshedData = await refreshRes.json();
    expect(refreshedData.refresh_token).toBeDefined();
    expect(refreshedData.refresh_token).not.toBe(initialRefreshToken);

    // 2. Reuse detected: Attempting to use the OLD refresh token must fail with 401
    const reuseRes = await app.request("/v1/auth/refresh", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: initialRefreshToken }),
    });
    expect(reuseRes.status).toBe(401);
  });
});
