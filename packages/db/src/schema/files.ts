import {
  pgTable,
  pgEnum,
  uuid,
  varchar,
  integer,
  index,
} from "drizzle-orm/pg-core";
import { notes } from "./notes.js";

export const fileKindEnum = pgEnum("file_kind", ["pdf", "timeline", "image"]);

export const files = pgTable(
  "files",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    note_id: uuid("note_id")
      .notNull()
      .references(() => notes.id, { onDelete: "cascade" }),
    kind: fileKindEnum("kind").notNull(),
    storage_key: varchar("storage_key", { length: 512 }).notNull(),
    size_bytes: integer("size_bytes").notNull(),
    checksum: varchar("checksum", { length: 128 }).notNull(),
  },
  (table) => [
    index("idx_files_note_id").on(table.note_id),
  ]
);
