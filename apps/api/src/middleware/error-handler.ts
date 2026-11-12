import type { ErrorHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import { ZodError } from "zod";

export const errorHandler: ErrorHandler = (err, c) => {
  if (err instanceof HTTPException) {
    return c.json(
      { error: { code: `HTTP_${err.status}`, message: err.message } },
      err.status
    );
  }

  if (err instanceof ZodError) {
    console.error("Zod Validation Error:", JSON.stringify(err.flatten()));
    return c.json(
      {
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid request",
          details: err.flatten(),
        },
      },
      400
    );
  }

  console.error("Unhandled error:", err);
  return c.json(
    { error: { code: "INTERNAL_ERROR", message: "Internal server error" } },
    500
  );
};
