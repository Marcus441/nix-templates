import dotenv from "dotenv";

dotenv.config({ quiet: true });

/**
 * Fail fast on a missing required variable, at import time rather than at the
 * first request that needs it. Use it for anything the server genuinely cannot
 * run without:
 *
 *   export const DATABASE_URL = requireEnv("DATABASE_URL");
 *
 * Nothing is required by default, so a freshly initialised project starts and
 * tests clean with no .env at all.
 */
export function requireEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`${name} is not defined in the environment`);
  }

  return value;
}

export const DEVELOPMENT = process.env.NODE_ENV === "development";
export const TEST = process.env.NODE_ENV === "test";

export const SERVER_HOSTNAME = process.env.SERVER_HOSTNAME || "localhost";
export const SERVER_PORT = process.env.SERVER_PORT
  ? Number(process.env.SERVER_PORT)
  : 8080;

export const CORS_ALLOWED_ORIGINS = process.env.CORS_ALLOWED_ORIGINS
  ? process.env.CORS_ALLOWED_ORIGINS.split(",")
  : [];

export const server = {
  SERVER_HOSTNAME,
  SERVER_PORT,
};

// When integrating a database, create a database object to export all of
// the variables in a database variable object, similar to server seen above
