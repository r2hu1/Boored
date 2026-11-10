import { z } from "zod";

export const googleAuthRequestSchema = z.object({
  id_token: z.string(),
});

export const authTokensSchema = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
  expires_in: z.number(),
});

export const refreshRequestSchema = z.object({
  refresh_token: z.string(),
});

export type GoogleAuthRequest = z.infer<typeof googleAuthRequestSchema>;
export type AuthTokens = z.infer<typeof authTokensSchema>;
export type RefreshRequest = z.infer<typeof refreshRequestSchema>;
