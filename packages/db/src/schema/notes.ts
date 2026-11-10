import {
  pgTable,
  pgEnum,
  uuid,
  varchar,
  integer,
  timestamp,
  index,
  customType,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { users } from "./users.js";

export const noteStatusEnum = pgEnum("note_status", [
  "recording",
  "processing",
  "ready",
  "failed",
]);

const tsvector = customType<{ data: string }>({
  dataType() {
    return "tsvector";
  },
});

export const notes = pgTable(
  "notes",
  {
    id: uuid("id").primaryKey(),
    user_id: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    title: varchar("title", { length: 255 }).notNull(),
    status: noteStatusEnum("status").notNull().default("recording"),
    duration_ms: integer("duration_ms"),
    started_at: timestamp("started_at", { withTimezone: true }),
    created_at: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updated_at: timestamp("updated_at", { withTimezone: true })
      .defaultNow()
      .notNull()
      .$onUpdate(() => new Date()),
    deleted_at: timestamp("deleted_at", { withTimezone: true }),
    version: integer("version").notNull().default(1),
    search_vector: tsvector("search_vector").generatedAlwaysAs(
      sql`to_tsvector('english', coalesce(title, ''))`
    ),
  },
  (table) => [
    index("idx_notes_user_id").on(table.user_id),
    index("idx_notes_updated_at").on(table.updated_at),
    index("idx_notes_user_updated").on(table.user_id, table.updated_at),
    index("idx_notes_search").using("gin", table.search_vector),
  ]
);
