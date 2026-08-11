import { Request, Response, NextFunction } from "express";
import { CORS_ALLOWED_ORIGINS } from "../config/config.js";

export function corsHandler(req: Request, res: Response, next: NextFunction) {
  const origin = req.header("origin");

  if (origin && CORS_ALLOWED_ORIGINS.includes(origin)) {
    res.header("Access-Control-Allow-Origin", origin);
    res.header("Access-Control-Allow-Credentials", "true");
  }

  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization",
  );

  if (req.method === "OPTIONS") {
    res.header("Access-Control-Allow-Methods", "PUT, POST, PATCH, DELETE, GET");
    return res.status(200).json({});
  }

  next();
}
