import { z } from 'zod';
import { validationFailed } from './errors';

/** Envelope every successful response shares, so clients parse one shape. */
export interface ApiEnvelope<T> {
  data: T;
  meta?: Record<string, unknown>;
}

export function ok<T>(data: T, meta?: Record<string, unknown>): ApiEnvelope<T> {
  return meta ? { data, meta } : { data };
}

/** Parse-or-throw. Zod issues are flattened into a field -> message map. */
export function parse<S extends z.ZodTypeAny>(schema: S, input: unknown): z.infer<S> {
  const result = schema.safeParse(input);
  if (result.success) return result.data;

  const fieldErrors: Record<string, string> = {};
  for (const issue of result.error.issues) {
    const key = issue.path.join('.') || '_';
    if (!(key in fieldErrors)) fieldErrors[key] = issue.message;
  }
  throw validationFailed(fieldErrors);
}
