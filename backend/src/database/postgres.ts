import pg from "pg";

const { Pool } = pg;

export function createPostgresPool(connectionString: string): pg.Pool {
  return new Pool({
    connectionString,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000
  });
}
