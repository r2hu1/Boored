import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  index,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { users } from "./users.js";

export const refreshTokens = pgTable(
  "refresh_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    user_id: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    token_hash: varchar("token_hash", { length: 512 }).notNull(),
    family_id: uuid("family_id").notNull(),
    expires_at: timestamp("expires_at", { withTimezone: true }).notNull(),
    revoked_at: timestamp("revoked_at", { withTimezone: true }),
    created_at: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index("idx_refresh_tokens_user_id").on(table.user_id),
    index("idx_refresh_tokens_family_id").on(table.family_id),
    uniqueIndex("idx_refresh_tokens_token_hash").on(table.token_hash),
  ]
);
