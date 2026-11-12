import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";
import { HTTPException } from "hono/http-exception";
import { eq } from "drizzle-orm";
import { randomUUID } from "node:crypto";
import { users, refreshTokens } from "@boored/db";
import { getDb } from "../db.js";
import {
  verifyGoogleIdToken,
  signAccessToken,
  hashToken,
} from "../services/jwt.js";
import { env } from "../env.js";

const authRoute = new OpenAPIHono();

// Schemas
const GoogleAuthBody = z.object({
  id_token: z.string().min(1).openapi({
    example: "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
    description: "Google ID Token returned from mobile Google Sign-In",
  }),
});

const RefreshBody = z.object({
  refresh_token: z.string().min(1).openapi({
    example: "dGhpcy1pcy1hLXJlZnJlc2gtdG9rZW4=",
  }),
});

const TokenResponse = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
  expires_in: z.number(),
  user: z.object({
    id: z.string().uuid(),
    email: z.string().email(),
    name: z.string(),
    avatar_url: z.string().nullable(),
  }),
});

// 1. POST /v1/auth/google
const googleRoute = createRoute({
  method: "post",
  path: "/auth/google",
  request: {
    body: {
      content: { "application/json": { schema: GoogleAuthBody } },
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TokenResponse } },
      description: "User authenticated and tokens issued",
    },
    400: { description: "Invalid token or request" },
    401: { description: "Google verification failed" },
  },
});

authRoute.openapi(googleRoute, async (c) => {
  const { id_token } = c.req.valid("json");
  const db = getDb();

  let googleUser;
  try {
    googleUser = await verifyGoogleIdToken(id_token);
  } catch (err: any) {
    throw new HTTPException(401, {
      message: `Invalid Google ID token: ${err.message}`,
    });
  }

  // Upsert user by google_sub
  const [existingUser] = await db
    .select()
    .from(users)
    .where(eq(users.google_sub, googleUser.sub))
    .limit(1);

  let userId: string;
  let userRecord;

  if (existingUser) {
    userId = existingUser.id;
    const [updated] = await db
      .update(users)
      .set({
        name: googleUser.name,
        avatar_url: googleUser.picture ?? existingUser.avatar_url,
      })
      .where(eq(users.id, userId))
      .returning();
    userRecord = updated;
  } else {
    const [created] = await db
      .insert(users)
      .values({
        google_sub: googleUser.sub,
        email: googleUser.email,
        name: googleUser.name,
        avatar_url: googleUser.picture ?? null,
      })
      .returning();
    userId = created.id;
    userRecord = created;
  }

  // Issue Access Token + Refresh Token
  const accessToken = await signAccessToken({
    sub: userId,
    email: userRecord.email,
  });

  const rawRefreshToken = randomUUID();
  const familyId = randomUUID();
  const tokenHashed = hashToken(rawRefreshToken);

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30); // 30 days

  await db.insert(refreshTokens).values({
    user_id: userId,
    token_hash: tokenHashed,
    family_id: familyId,
    expires_at: expiresAt,
  });

  return c.json(
    {
      access_token: accessToken,
      refresh_token: rawRefreshToken,
      expires_in: 900, // 15 mins (in seconds)
      user: {
        id: userRecord.id,
        email: userRecord.email,
        name: userRecord.name,
        avatar_url: userRecord.avatar_url,
      },
    },
    200
  );
});

// 2. POST /v1/auth/refresh (Rotating refresh token with family reuse detection)
const refreshRoute = createRoute({
  method: "post",
  path: "/auth/refresh",
  request: {
    body: {
      content: { "application/json": { schema: RefreshBody } },
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TokenResponse } },
      description: "Tokens successfully rotated",
    },
    401: { description: "Invalid or revoked refresh token" },
  },
});

authRoute.openapi(refreshRoute, async (c) => {
  const { refresh_token } = c.req.valid("json");
  const db = getDb();
  const incomingHash = hashToken(refresh_token);

  const [storedToken] = await db
    .select()
    .from(refreshTokens)
    .where(eq(refreshTokens.token_hash, incomingHash))
    .limit(1);

  if (!storedToken) {
    throw new HTTPException(401, { message: "Invalid refresh token" });
  }

  // TOKEN REUSE DETECTION: If this token was already revoked, revoke the ENTIRE family
  if (storedToken.revoked_at !== null) {
    await db
      .update(refreshTokens)
      .set({ revoked_at: new Date() })
      .where(eq(refreshTokens.family_id, storedToken.family_id));

    throw new HTTPException(401, {
      message: "Refresh token reuse detected. Family revoked.",
    });
  }

  // Check expiration
  if (new Date() > storedToken.expires_at) {
    throw new HTTPException(401, { message: "Refresh token expired" });
  }

  // Revoke current token
  await db
    .update(refreshTokens)
    .set({ revoked_at: new Date() })
    .where(eq(refreshTokens.id, storedToken.id));

  // Fetch user
  const [user] = await db
    .select()
    .from(users)
    .where(eq(users.id, storedToken.user_id))
    .limit(1);

  if (!user) {
    throw new HTTPException(401, { message: "User not found" });
  }

  // Issue new token pair under same family
  const newAccessToken = await signAccessToken({
    sub: user.id,
    email: user.email,
  });

  const newRefreshToken = randomUUID();
  const newExpiresAt = new Date();
  newExpiresAt.setDate(newExpiresAt.getDate() + 30);

  await db.insert(refreshTokens).values({
    user_id: user.id,
    token_hash: hashToken(newRefreshToken),
    family_id: storedToken.family_id,
    expires_at: newExpiresAt,
  });

  return c.json(
    {
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      expires_in: 900,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatar_url: user.avatar_url,
      },
    },
    200
  );
});

// 3. POST /v1/auth/logout
const logoutRoute = createRoute({
  method: "post",
  path: "/auth/logout",
  request: {
    body: {
      content: { "application/json": { schema: RefreshBody } },
    },
  },
  responses: {
    200: {
      content: {
        "application/json": {
          schema: z.object({ success: z.boolean() }),
        },
      },
      description: "Logged out",
    },
  },
});

authRoute.openapi(logoutRoute, async (c) => {
  const { refresh_token } = c.req.valid("json");
  const db = getDb();
  const incomingHash = hashToken(refresh_token);

  await db
    .update(refreshTokens)
    .set({ revoked_at: new Date() })
    .where(eq(refreshTokens.token_hash, incomingHash));

  return c.json({ success: true }, 200);
});

export { authRoute };
