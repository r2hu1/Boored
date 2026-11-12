import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";
import { and, eq, sql } from "drizzle-orm";
import { requireAuth, type AuthContext } from "../middleware/auth.js";
import { getDb } from "../db.js";
import { notes } from "@boored/db";

const searchRoute = new OpenAPIHono<AuthContext>();

const searchResultsRoute = createRoute({
  method: "get",
  path: "/search",
  middleware: [requireAuth],
  request: {
    query: z.object({
      q: z.string().min(1),
    }),
  },
  responses: {
    200: {
      content: {
        "application/json": {
          schema: z.object({
            results: z.array(
              z.object({
                id: z.string().uuid(),
                title: z.string(),
                status: z.string(),
                created_at: z.string(),
              })
            ),
          }),
        },
      },
      description: "Search results matching query",
    },
    401: { description: "Unauthorized" },
  },
});

searchRoute.openapi(searchResultsRoute, async (c) => {
  const user = c.get("user");
  const { q } = c.req.valid("query");
  const db = getDb();

  const formattedQuery = q.trim().replace(/\s+/g, " & ");

  const matchingNotes = await db
    .select({
      id: notes.id,
      title: notes.title,
      status: notes.status,
      created_at: notes.created_at,
    })
    .from(notes)
    .where(
      and(
        eq(notes.user_id, user.sub),
        sql`${notes.search_vector} @@ to_tsquery('english', ${formattedQuery})`
      )
    )
    .limit(20);

  return c.json(
    {
      results: matchingNotes.map((n) => ({
        id: n.id,
        title: n.title,
        status: n.status,
        created_at: n.created_at.toISOString(),
      })),
    },
    200
  );
});

export { searchRoute };
