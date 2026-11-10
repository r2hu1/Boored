import {
  pgTable,
  uuid,
  varchar,
  text,
  timestamp,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  google_sub: varchar("google_sub", { length: 255 }).unique().notNull(),
  email: varchar("email", { length: 255 }).notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  avatar_url: text("avatar_url"),
  created_at: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
