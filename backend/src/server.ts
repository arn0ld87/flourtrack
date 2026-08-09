import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify from "fastify";
import { createPostgresPool } from "./database/postgres.js";
import { createRedisClient } from "./redis/client.js";

const port = Number(process.env.PORT ?? 8080);
const databaseUrl = process.env.DATABASE_URL;
const redisUrl = process.env.REDIS_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

if (!redisUrl) {
  throw new Error("REDIS_URL is required");
}

const postgres = createPostgresPool(databaseUrl);
const redis = createRedisClient(redisUrl);

const app = Fastify({
  logger: {
    level: process.env.NODE_ENV === "production" ? "info" : "debug",
    redact: ["req.headers.authorization", "DATABASE_URL", "REDIS_URL"]
  }
});

await app.register(helmet);
await app.register(cors, {
  origin: (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean)
});
await app.register(rateLimit, {
  max: Number(process.env.RATE_LIMIT_MAX ?? 120),
  timeWindow: process.env.RATE_LIMIT_WINDOW ?? "1 minute"
});

app.get("/health/live", async () => ({
  status: "ok",
  service: "flourtrack-backend"
}));

app.get("/health/ready", async (_request, reply) => {
  try {
    await postgres.query("select 1");
    await redis.ping();
    return {
      status: "ready",
      postgres: "ok",
      redis: "ok"
    };
  } catch (error) {
    app.log.error({ error }, "readiness check failed");
    return reply.code(503).send({
      status: "not_ready"
    });
  }
});

app.get("/", async () => ({
  name: "FlourTrack API",
  version: "0.1.0",
  docs: "/openapi.json"
}));

app.get("/openapi.json", async () => ({
  openapi: "3.1.0",
  info: {
    title: "FlourTrack API",
    version: "0.1.0",
    description: "Phase 1 health and infrastructure contract. Game and social endpoints follow in later phases."
  },
  paths: {
    "/health/live": {
      get: {
        summary: "Liveness check",
        responses: {
          "200": {
            description: "Backend process is running"
          }
        }
      }
    },
    "/health/ready": {
      get: {
        summary: "Readiness check",
        responses: {
          "200": {
            description: "Backend can reach PostgreSQL and Redis"
          },
          "503": {
            description: "A dependency is not ready"
          }
        }
      }
    }
  }
}));

const shutdown = async () => {
  app.log.info("shutting down");
  await app.close();
  await postgres.end();
  redis.disconnect();
};

process.on("SIGTERM", () => {
  void shutdown();
});

process.on("SIGINT", () => {
  void shutdown();
});

await redis.connect();
await app.listen({ port, host: "0.0.0.0" });
