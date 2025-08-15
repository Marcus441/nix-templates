import { Request, Response, NextFunction } from "express";

export class CustomError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
    Object.setPrototypeOf(this, CustomError.prototype);
  }
}

export const errorHandler = (
  err: any,
  _req: Request,
  res: Response,
  _next: NextFunction,
) => {
  let statusCode = err.statusCode || 500;
  let message = err.message || "Internal Server Error";

  if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
    statusCode = 401;
    message = "Authentication failed: Invalid or expired token.";
  }

  if (err instanceof CustomError) {
    statusCode = err.statusCode;
    message = err.message;
  }

  if (statusCode >= 500) {
    console.error(`[Server Error] - ${err.stack}`);
    message = "Internal Server Error";
  }

  res.status(statusCode).json({
    success: false,
    message: message,
  });
};
