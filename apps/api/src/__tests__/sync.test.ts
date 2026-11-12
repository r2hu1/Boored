import { describe, it, expect, beforeAll } from "vitest";
import { createApp } from "../app.js";
import { signAccessToken } from "../services/jwt.js";
import { getDb } from "../db.js";
import { users, notes, keyframes } from "@boored/db";
import { eq } from "drizzle-orm";

describe("Sync Routes (/v1/sync/*)", () => {
  const app = createApp();
  const testUserId = "22222222-2222-2222-2222-222222222222";
  let authToken: string;

  beforeAll(async () => {
    const db = getDb();
    await db.delete(users).where(eq(users.id, testUserId));
    await db.insert(users).values({
      id: testUserId,
      google_sub: "google-sync-test-user",
      email: "synctest@example.com",
      name: "Sync Tester",
    });

    authToken = await signAccessToken({
      sub: testUserId,
      email: "synctest@example.com",
    });
  });

  it("POST /v1/sync/push rejects unauthenticated request with 401", async () => {
    const res = await app.request("/v1/sync/push", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ notes: [], keyframes: [] }),
    });
    expect(res.status).toBe(401);
  });

  it("POST /v1/sync/push accepts valid note and keyframe inserts", async () => {
    const noteId = "33333333-3333-4333-8333-333333333333";
    const kfId = "44444444-4444-4444-8444-444444444444";

    const res = await app.request("/v1/sync/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        notes: [
          {
            id: noteId,
            title: "Remote Physics Note",
            status: "ready",
            version: 1,
          },
        ],
        keyframes: [
          {
            id: kfId,
            note_id: noteId,
            index: 0,
            timestamp_ms: 1000,
            event_type: "NONE",
            image_key: "s3://boored/test.jpg",
          },
        ],
      }),
    });

    if (res.status !== 200) {
      console.log("Error details:", await res.json());
    }
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.acceptedNotes).toBe(1);
    expect(data.acceptedKeyframes).toBe(1);
  });

  it("GET /v1/sync/pull fetches modified notes since cursor", async () => {
    const res = await app.request("/v1/sync/pull", {
      method: "GET",
      headers: {
        Authorization: `Bearer ${authToken}`,
      },
    });

    expect(res.status).toBe(200);
    if (res.status !== 200) {
      console.log("Error details:", await res.json());
    }
    const data = await res.json();
    expect(Array.isArray(data.notes)).toBe(true);
    expect(data.notes.length).toBeGreaterThan(0);
    expect(data.cursor).toBeDefined();
  });
});
