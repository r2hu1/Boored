import postgres from "postgres";
import { drizzle } from "drizzle-orm/postgres-js";
import * as schema from "./schema/index.js";

export function createDb(url: string, poolSize = 10) {
  const client = postgres(url, { max: poolSize });
  return drizzle(client, { schema });
}

export type Database = ReturnType<typeof createDb>;
