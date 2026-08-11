import dotenv from "dotenv";

dotenv.config();

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

export const MY_APP_NAMESPACE = process.env.MY_APP_NAMESPACE;

if (!MY_APP_NAMESPACE) {
  throw new Error("MY_APP_NAMESPACE is not defined in environment variables.");
}
