import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";
import { HTTPException } from "hono/http-exception";
import { eq } from "drizzle-orm";
import { users } from "@boored/db";
import { getDb } from "../db.js";
import { requireAuth, type AuthContext } from "../middleware/auth.js";

const meRoute = new OpenAPIHono<AuthContext>();

const getMeRoute = createRoute({
  method: "get",
  path: "/me",
  security: [{ bearerAuth: [] }],
  responses: {
    200: {
      content: {
        "application/json": {
          schema: z.object({
            id: z.string().uuid(),
            email: z.string().email(),
            name: z.string(),
            avatar_url: z.string().nullable(),
            created_at: z.string(),
          }),
        },
      },
      description: "Current authenticated user profile",
    },
    401: {
      content: {
        "application/json": {
          schema: z.object({
            error: z.object({
              code: z.string(),
              message: z.string(),
            }),
          }),
        },
      },
      description: "Unauthorized",
    },
  },
});

meRoute.use("/me", requireAuth);

meRoute.openapi(getMeRoute, async (c) => {
  const authUser = c.get("user");
  const db = getDb();

  const [user] = await db
    .select()
    .from(users)
    .where(eq(users.id, authUser.sub))
    .limit(1);

  if (!user) {
    throw new HTTPException(404, { message: "User not found" });
  }

  return c.json(
    {
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      created_at: user.created_at.toISOString(),
    },
    200
  );
});

export { meRoute };
