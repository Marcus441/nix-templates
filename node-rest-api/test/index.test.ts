import { describe, it, expect, afterAll, beforeAll } from "vitest";
import request from "supertest";
import { app, SetupApplication, Shutdown } from "../src/index.js";

beforeAll(() => {
  SetupApplication();
});

afterAll((done) => {
  Shutdown(done);
});

describe("Environment", () => {
  it("Has the proper test environment", async () => {
    expect(process.env.NODE_ENV).toBe("test");
  }, 10000);

  it("Returns all options and can be accessed by customers (http)", async () => {
    const response = await request(app).options("/");

    expect(response.status).toBe(200);
    expect(response.headers["access-control-allow-methods"]).toBe(
      "PUT, POST, PATCH, DELETE, GET",
    );
  });
});

describe("Healthcheck API Endpoint", () => {
  it("should return 200 OK and a status of 'ok'", async () => {
    const response = await request(app).get("/main/healthcheck");

    expect(response.status).toBe(200);

    expect(response.body).toEqual({ status: "ok" });
  });
});
