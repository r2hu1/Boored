import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";

const healthRoute = new OpenAPIHono();

const route = createRoute({
  method: "get",
  path: "/health",
  responses: {
    200: {
      content: {
        "application/json": {
          schema: z.object({
            status: z.string().openapi({ example: "ok" }),
            timestamp: z.string().openapi({ example: "2026-01-01T00:00:00.000Z" }),
          }),
        },
      },
      description: "Health check",
    },
  },
});

healthRoute.openapi(route, (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() }, 200);
});

export { healthRoute };
