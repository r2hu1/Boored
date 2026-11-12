import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";
import { eq, and, gt, desc } from "drizzle-orm";
import { requireAuth, type AuthContext } from "../middleware/auth.js";
import { getDb } from "../db.js";
import { notes, keyframes } from "@boored/db";

const syncRoute = new OpenAPIHono<AuthContext>();

const NoteSyncItem = z.object({
  id: z.string().uuid(),
  title: z.string(),
  status: z.enum(["recording", "processing", "ready", "failed"]),
  duration_ms: z.number().int().nullable().optional(),
  created_at: z.string().datetime().optional(),
  updated_at: z.string().datetime().optional(),
  deleted_at: z.string().datetime().nullable().optional(),
  version: z.number().int(),
});

const KeyframeSyncItem = z.object({
  id: z.string().uuid(),
  note_id: z.string().uuid(),
  index: z.number().int(),
  timestamp_ms: z.number().int(),
  event_type: z.enum(["ADD", "ERASE", "NONE"]).default("NONE"),
  image_key: z.string().default("local"),
});

const SyncPushBody = z.object({
  notes: z.array(NoteSyncItem).default([]),
  keyframes: z.array(KeyframeSyncItem).default([]),
});

const SyncPushResponse = z.object({
  acceptedNotes: z.number().int(),
  acceptedKeyframes: z.number().int(),
});

const SyncPullResponse = z.object({
  notes: z.array(
    z.object({
      id: z.string().uuid(),
      title: z.string(),
      status: z.string(),
      updated_at: z.string(),
      deleted_at: z.string().nullable(),
      version: z.number().int(),
    })
  ),
  cursor: z.string().nullable(),
});

// POST /v1/sync/push
const pushRoute = createRoute({
  method: "post",
  path: "/sync/push",
  middleware: [requireAuth],
  request: {
    body: {
      content: { "application/json": { schema: SyncPushBody } },
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: SyncPushResponse } },
      description: "Pushed changes processed",
    },
    401: { description: "Unauthorized" },
  },
});

syncRoute.openapi(pushRoute, async (c) => {
  const user = c.get("user");
  const { notes: incomingNotes, keyframes: incomingKeyframes } = c.req.valid("json");
  const db = getDb();

  let acceptedNotes = 0;
  let acceptedKeyframes = 0;

  for (const n of incomingNotes) {
    const [existing] = await db
      .select()
      .from(notes)
      .where(and(eq(notes.id, n.id), eq(notes.user_id, user.sub)))
      .limit(1);

    if (existing) {
      if (n.version >= existing.version) {
        await db
          .update(notes)
          .set({
            title: n.title,
            status: n.status,
            duration_ms: n.duration_ms ?? existing.duration_ms,
            deleted_at: n.deleted_at ? new Date(n.deleted_at) : null,
            version: n.version,
            updated_at: new Date(),
          })
          .where(eq(notes.id, n.id));
        acceptedNotes++;
      }
    } else {
      await db.insert(notes).values({
        id: n.id,
        user_id: user.sub,
        title: n.title,
        status: n.status,
        duration_ms: n.duration_ms ?? null,
        version: n.version,
      });
      acceptedNotes++;
    }
  }

  for (const k of incomingKeyframes) {
    const [existing] = await db
      .select()
      .from(keyframes)
      .where(eq(keyframes.id, k.id))
      .limit(1);

    if (!existing) {
      await db.insert(keyframes).values({
        id: k.id,
        note_id: k.note_id,
        index: k.index,
        timestamp_ms: k.timestamp_ms,
        event_type: k.event_type,
        image_key: k.image_key,
      });
      acceptedKeyframes++;
    }
  }

  return c.json({ acceptedNotes, acceptedKeyframes }, 200);
});

// GET /v1/sync/pull
const pullRoute = createRoute({
  method: "get",
  path: "/sync/pull",
  middleware: [requireAuth],
  request: {
    query: z.object({
      cursor: z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: SyncPullResponse } },
      description: "Changes since cursor",
    },
    401: { description: "Unauthorized" },
  },
});

syncRoute.openapi(pullRoute, async (c) => {
  const user = c.get("user");
  const { cursor } = c.req.valid("query");
  const db = getDb();

  const cursorDate = cursor ? new Date(cursor) : new Date(0);

  const modifiedNotes = await db
    .select()
    .from(notes)
    .where(and(eq(notes.user_id, user.sub), gt(notes.updated_at, cursorDate)))
    .orderBy(desc(notes.updated_at))
    .limit(50);

  const nextCursor =
    modifiedNotes.length > 0
      ? modifiedNotes[0].updated_at.toISOString()
      : cursor ?? null;

  return c.json(
    {
      notes: modifiedNotes.map((n) => ({
        id: n.id,
        title: n.title,
        status: n.status,
        updated_at: n.updated_at.toISOString(),
        deleted_at: n.deleted_at ? n.deleted_at.toISOString() : null,
        version: n.version,
      })),
      cursor: nextCursor,
    },
    200
  );
});

export { syncRoute };
