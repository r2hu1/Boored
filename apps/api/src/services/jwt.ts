import { SignJWT, jwtVerify, createRemoteJWKSet } from "jose";
import { createHash } from "node:crypto";
import { env } from "../env.js";

const GOOGLE_JWKS_URL = new URL("https://www.googleapis.com/oauth2/v3/certs");
const googleJWKS = createRemoteJWKSet(GOOGLE_JWKS_URL);

const secretKey = new TextEncoder().encode(env.JWT_SECRET);

export interface GooglePayload {
  sub: string;
  email: string;
  name: string;
  picture?: string;
}

export interface AccessTokenPayload {
  sub: string; // user id (uuid)
  email: string;
}

/**
 * Hash a refresh token using SHA-256 for secure DB storage.
 */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/**
 * Verifies a Google ID token against Google's public JWKS.
 * Checks audience, issuer, and expiration.
 */
export async function verifyGoogleIdToken(idToken: string): Promise<GooglePayload> {
  const { payload } = await jwtVerify(idToken, googleJWKS, {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    audience: env.GOOGLE_CLIENT_ID,
  });

  if (!payload.sub || !payload.email) {
    throw new Error("Invalid Google token payload");
  }

  return {
    sub: payload.sub as string,
    email: payload.email as string,
    name: (payload.name as string) || (payload.email as string).split("@")[0] || "User",
    picture: payload.picture as string | undefined,
  };
}

/**
 * Issues a short-lived access token (JWT).
 */
export async function signAccessToken(payload: AccessTokenPayload): Promise<string> {
  return new SignJWT({ email: payload.email })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime(env.JWT_ACCESS_EXPIRES_IN)
    .sign(secretKey);
}

/**
 * Verifies an access token (JWT).
 */
export async function verifyAccessToken(token: string): Promise<AccessTokenPayload> {
  const { payload } = await jwtVerify(token, secretKey);
  if (!payload.sub) {
    throw new Error("Invalid token subject");
  }
  return {
    sub: payload.sub,
    email: (payload.email as string) || "",
  };
}
