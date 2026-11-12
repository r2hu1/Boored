import { OpenAPIHono } from "@hono/zod-openapi";
import { logger } from "hono/logger";
import { cors } from "hono/cors";
import { secureHeaders } from "hono/secure-headers";
import { requestId } from "hono/request-id";
import { apiReference } from "@scalar/hono-api-reference";
import { env } from "./env.js";
import { healthRoute } from "./routes/health.js";
import { authRoute } from "./routes/auth.js";
import { meRoute } from "./routes/me.js";
import { errorHandler } from "./middleware/error-handler.js";

export function createApp() {
  const app = new OpenAPIHono();

  app.use("*", requestId());
  app.use("*", logger());
  app.use("*", secureHeaders());
  app.use("*", cors({ origin: env.CORS_ORIGIN, credentials: true }));
  app.onError(errorHandler);

  app.route("/v1", healthRoute);
  app.route("/v1", authRoute);
  app.route("/v1", meRoute);

  app.doc("/v1/openapi.json", {
    openapi: "3.1.0",
    info: {
      title: "Boored API",
      version: "0.1.0",
      description: "Boored classroom whiteboard digitization API",
    },
  });

  if (env.NODE_ENV === "development") {
    app.get("/v1/docs", apiReference({ spec: { url: "/v1/openapi.json" } }));
  }

  return app;
}
