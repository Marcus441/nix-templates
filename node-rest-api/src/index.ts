import express from "express";
import http, { Server } from "http";
import { loggingHandler } from "./middleware/loggingHandler.js";
import { corsHandler } from "./middleware/corsHandler.js";
import { routeNotFound } from "./middleware/routeNotFound.js";
import { server } from "./config/config.js";
import { errorHandler } from "./middleware/errorHandler.js";

export const app = express();

export let httpServer: Server;

export const SetupApplication = () => {
  console.log("----------------------------------------");
  console.log("Initializing API");
  console.log("----------------------------------------");
  app.use(express.urlencoded({ extended: true }));
  app.use(express.json());

  console.log("----------------------------------------");
  console.log("Logging & Configuration");
  console.log("----------------------------------------");
  app.use(loggingHandler);
  app.use(corsHandler);

  console.log("----------------------------------------");
  console.log("Define Controller Routing");
  console.log("----------------------------------------");
  app.get("/main/healthcheck", (_req, res, _next) => {
    return res.status(200).json({ status: "ok" });
  });

  console.log("----------------------------------------");
  console.log("Define Error Handling");
  console.log("----------------------------------------");
  app.use(routeNotFound);
  app.use(errorHandler);
};

export const StartServer = () => {
  console.log("----------------------------------------");
  console.log("Starting Server");
  console.log("----------------------------------------");
  httpServer = http.createServer(app);
  httpServer.listen(server.SERVER_PORT, () => {
    console.log("----------------------------------------");
    console.log(
      `Server started on ${server.SERVER_HOSTNAME}:${server.SERVER_PORT}`,
    );
    console.log("----------------------------------------");
  });
};

export const Shutdown = (callback: any) =>
  httpServer && httpServer.close(callback);

const isMainModule = (url: string) => {
  const file = new URL(url).pathname;
  return process.argv[1] === file;
};

if (isMainModule(import.meta.url)) {
  SetupApplication();
  StartServer();
}
