import { createDb, type Database } from "@boored/db";
import { env } from "./env.js";

let _db: Database | null = null;

export function getDb(): Database {
  if (!_db) {
    _db = createDb(env.DATABASE_URL, env.DATABASE_POOL_SIZE);
  }
  return _db;
}
