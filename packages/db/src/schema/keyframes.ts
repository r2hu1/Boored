import {
  pgTable,
  pgEnum,
  uuid,
  integer,
  varchar,
  jsonb,
  index,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { notes } from "./notes.js";

export const eventTypeEnum = pgEnum("event_type", ["ADD", "ERASE", "NONE"]);

export const keyframes = pgTable(
  "keyframes",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    note_id: uuid("note_id")
      .notNull()
      .references(() => notes.id, { onDelete: "cascade" }),
    index: integer("index").notNull(),
    timestamp_ms: integer("timestamp_ms").notNull(),
    event_type: eventTypeEnum("event_type").notNull().default("NONE"),
    image_key: varchar("image_key", { length: 512 }).notNull(),
    thumbnail_key: varchar("thumbnail_key", { length: 512 }),
    diff_boxes: jsonb("diff_boxes").default([]),
  },
  (table) => [
    index("idx_keyframes_note_id").on(table.note_id),
    uniqueIndex("uq_keyframes_note_index").on(table.note_id, table.index),
  ]
);
