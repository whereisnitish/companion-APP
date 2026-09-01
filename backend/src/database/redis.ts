import Redis from 'ioredis';
import { env, isTest } from '../config/env';

/**
 * Redis is an accelerator here, never a dependency: caching, presence and
 * quota counters. Every call site degrades gracefully when it is unavailable,
 * so `docker compose` without Redis still yields a working API.
 */
let client: Redis | null = null;
let healthy = false;
let givenUp = false;

/** Stop reconnecting after this many failed attempts. */
const MAX_RECONNECT_ATTEMPTS = 10;

export function getRedis(): Redis | null {
  // Tests run without Redis; a retrying client would keep the process alive.
  if (isTest || givenUp) return null;
  if (client) return client;

  client = new Redis(env.REDIS_URL, {
    lazyConnect: false,
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
    retryStrategy: (times) => {
      // Give up rather than reconnecting forever — an absent Redis must not
      // hold the event loop open or drown the logs.
      if (times > MAX_RECONNECT_ATTEMPTS) {
        givenUp = true;
        healthy = false;
        client?.disconnect();
        client = null;
        return null;
      }
      return Math.min(times * 500, 5000);
    },
  });

  client.on('ready', () => {
    healthy = true;
  });
  client.on('error', () => {
    healthy = false;
  });

  return client;
}

export const isRedisHealthy = (): boolean => healthy;

export async function cacheGet<T>(key: string): Promise<T | null> {
  const redis = getRedis();
  if (!redis || !healthy) return null;
  try {
    const raw = await redis.get(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

export async function cacheSet(key: string, value: unknown, ttlSeconds: number): Promise<void> {
  const redis = getRedis();
  if (!redis || !healthy) return;
  try {
    await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  } catch {
    /* cache writes are best-effort */
  }
}

export async function cacheDeleteByPrefix(prefix: string): Promise<void> {
  const redis = getRedis();
  if (!redis || !healthy) return;
  try {
    const stream = redis.scanStream({ match: `${prefix}*`, count: 100 });
    for await (const keys of stream as AsyncIterable<string[]>) {
      if (keys.length) await redis.del(...keys);
    }
  } catch {
    /* best-effort */
  }
}

/** Fixed-window counter used for cheap per-user quotas. Returns the new count. */
export async function incrementCounter(key: string, ttlSeconds: number): Promise<number> {
  const redis = getRedis();
  if (!redis || !healthy) return 0;
  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, ttlSeconds);
    return count;
  } catch {
    return 0;
  }
}

export async function setPresence(userId: string, ttlSeconds: number): Promise<void> {
  const redis = getRedis();
  if (!redis || !healthy) return;
  try {
    await redis.set(`presence:${userId}`, Date.now().toString(), 'EX', ttlSeconds);
  } catch {
    /* best-effort */
  }
}

export async function getPresence(userIds: string[]): Promise<Set<string>> {
  const online = new Set<string>();
  const redis = getRedis();
  if (!redis || !healthy || userIds.length === 0) return online;
  try {
    const values = await redis.mget(userIds.map((id) => `presence:${id}`));
    userIds.forEach((id, index) => {
      if (values[index]) online.add(id);
    });
  } catch {
    /* best-effort */
  }
  return online;
}

export async function disconnectRedis(): Promise<void> {
  if (client) {
    await client.quit().catch(() => undefined);
    client.disconnect();
    client = null;
  }
  healthy = false;
}
