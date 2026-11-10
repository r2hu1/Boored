import { z } from "zod";

export const eventTypeEnum = z.enum(["ADD", "ERASE", "NONE"]);

export const bboxSchema = z.object({
  x: z.number(),
  y: z.number(),
  w: z.number(),
  h: z.number(),
});

export const keyframeSchema = z.object({
  id: z.string().uuid(),
  note_id: z.string().uuid(),
  index: z.number().int(),
  timestamp_ms: z.number().int(),
  event_type: eventTypeEnum,
  image_key: z.string(),
  thumbnail_key: z.string().nullable(),
  diff_boxes: z.array(bboxSchema),
});

export const keyframeBatchUpsertSchema = z.object({
  keyframes: z.array(keyframeSchema).max(100),
});

export type EventType = z.infer<typeof eventTypeEnum>;
export type BBox = z.infer<typeof bboxSchema>;
export type Keyframe = z.infer<typeof keyframeSchema>;
export type KeyframeBatchUpsert = z.infer<typeof keyframeBatchUpsertSchema>;
