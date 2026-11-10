import {
  pgTable,
  pgEnum,
  uuid,
  jsonb,
  text,
  real,
  boolean,
  index,
} from "drizzle-orm/pg-core";
import { keyframes } from "./keyframes.js";

export const regionTypeEnum = pgEnum("region_type", [
  "text",
  "math",
  "table",
  "diagram",
]);

export const regions = pgTable(
  "regions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    keyframe_id: uuid("keyframe_id")
      .notNull()
      .references(() => keyframes.id, { onDelete: "cascade" }),
    type: regionTypeEnum("type").notNull(),
    bbox: jsonb("bbox").notNull(),
    text: text("text").notNull().default(""),
    confidence: real("confidence").notNull().default(0),
    edited_by_user: boolean("edited_by_user").notNull().default(false),
  },
  (table) => [
    index("idx_regions_keyframe_id").on(table.keyframe_id),
  ]
);
