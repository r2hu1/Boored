import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";
import { verifyAccessToken, type AccessTokenPayload } from "../services/jwt.js";

export type AuthContext = {
  Variables: {
    user: AccessTokenPayload;
  };
};

export const requireAuth = createMiddleware<AuthContext>(async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new HTTPException(401, {
      message: "Missing or invalid Authorization header",
    });
  }

  const token = authHeader.substring(7);
  try {
    const payload = await verifyAccessToken(token);
    c.set("user", payload);
    await next();
  } catch {
    throw new HTTPException(401, {
      message: "Invalid or expired access token",
    });
  }
});
