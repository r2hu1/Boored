import { z } from "zod";
import { bboxSchema } from "./keyframe.js";

export const regionTypeEnum = z.enum(["text", "math", "table", "diagram"]);

export const regionSchema = z.object({
  id: z.string().uuid(),
  keyframe_id: z.string().uuid(),
  type: regionTypeEnum,
  bbox: bboxSchema,
  text: z.string(),
  confidence: z.number().min(0).max(1),
  edited_by_user: z.boolean(),
});

export type RegionType = z.infer<typeof regionTypeEnum>;
export type Region = z.infer<typeof regionSchema>;
