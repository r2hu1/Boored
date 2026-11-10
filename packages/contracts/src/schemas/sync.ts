import { z } from "zod";

export const syncPullResponseSchema = z.object({
  changes: z.array(z.any()),
  cursor: z.string().nullable(),
  has_more: z.boolean(),
});

export const syncPushRequestSchema = z.object({
  changes: z.array(
    z.object({
      table: z.string(),
      operation: z.enum(["upsert", "delete"]),
      data: z.any(),
      version: z.number().int(),
    })
  ),
});

export const syncPushResponseSchema = z.object({
  accepted: z.number().int(),
  conflicts: z.array(z.any()),
});

export type SyncPullResponse = z.infer<typeof syncPullResponseSchema>;
export type SyncPushRequest = z.infer<typeof syncPushRequestSchema>;
export type SyncPushResponse = z.infer<typeof syncPushResponseSchema>;
