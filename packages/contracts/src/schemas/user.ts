import { z } from "zod";

export const userSchema = z.object({
  id: z.string().uuid(),
  google_sub: z.string(),
  email: z.string().email(),
  name: z.string(),
  avatar_url: z.string().url().nullable(),
  created_at: z.string().datetime(),
});

export const meResponseSchema = userSchema;

export type User = z.infer<typeof userSchema>;
export type MeResponse = z.infer<typeof meResponseSchema>;
