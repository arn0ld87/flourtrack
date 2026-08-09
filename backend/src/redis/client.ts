import { Redis } from "ioredis";

export function createRedisClient(redisUrl: string): Redis {
  return new Redis(redisUrl, {
    maxRetriesPerRequest: 2,
    enableReadyCheck: true,
    lazyConnect: true
  });
}
