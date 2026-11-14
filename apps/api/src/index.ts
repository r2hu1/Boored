import { Hono } from "hono";
import { serve } from "@hono/node-server";
import { env } from "./env.js";
import { createApp } from "./app.js";

// 1. Create root Hono instance for Vercel's zero-config detector
const app = new Hono();

// 2. Mount the OpenAPI application
const apiApp = createApp();
app.route("/", apiApp);

// 3. Local standalone development server
if (process.env.NODE_ENV !== "production" || !process.env.VERCEL) {
  console.log(`Starting Boored API on ${env.API_HOST}:${env.API_PORT}`);

  serve({
    fetch: app.fetch,
    hostname: env.API_HOST,
    port: env.API_PORT,
  });

  console.log(`Boored API running at http://${env.API_HOST}:${env.API_PORT}`);
  if (env.NODE_ENV === "development") {
    console.log(`API docs: http://localhost:${env.API_PORT}/v1/docs`);
    console.log(`OpenAPI spec: http://localhost:${env.API_PORT}/v1/openapi.json`);
  }
}

// 4. Default export of standard Hono instance for Vercel
export default app;
