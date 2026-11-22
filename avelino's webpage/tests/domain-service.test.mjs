import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createServer } from "vite";

let server;
let domain;
let service;
const storage = new Map();
globalThis.sessionStorage = {
  getItem: (key) => storage.get(key) ?? null,
  setItem: (key, value) => storage.set(key, value),
  removeItem: (key) => storage.delete(key),
};

const reply = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { "content-type": "application/json" },
});

before(async () => {
  server = await createServer({ server: { middlewareMode: true } });
  domain = await server.ssrLoadModule("/src/utils/domain.js");
  ({ apiService: service } = await server.ssrLoadModule("/src/services/apiService.js"));
});
after(async () => { await server?.close(); });

test("account email accepts real school addresses and rejects malformed addresses", () => {
  assert.equal(domain.schoolEmail("jsgarque@fit.edu.ph"), true);
  assert.equal(domain.schoolEmail("admin@example.com"), true);
  assert.equal(domain.schoolEmail("@fit.edu.ph"), false);
  assert.equal(domain.schoolEmail("a@@fit.edu.ph"), false);
});

test("inventory failure never falls back to sample products", async () => {
  service.clearSession();
  globalThis.fetch = async () => reply({ detail: "Sign in required" }, 401);
  const response = await service.listProducts();
  assert.equal(response.ok, false);
  assert.match(response.error.message, /Sign in required/);
});

test("email challenge must be verified before a browser session is stored", async () => {
  service.clearSession();
  const paths = [];
  globalThis.fetch = async (url, options) => {
    paths.push(new URL(url, "https://example.test").pathname);
    if (url.endsWith("/auth/login")) return reply({ verification_required: true, challenge_id: "challenge-1", email: "student@fit.edu.ph" });
    if (url.endsWith("/auth/verify")) {
      assert.deepEqual(JSON.parse(options.body), { challenge_id: "challenge-1", code: "123456" });
      return reply({ token: "signed-token" });
    }
    if (url.endsWith("/me")) return reply({ id: "student-1", role: "STUDENT", name: "Test Student", email: "student@fit.edu.ph", account_id: "2026-0001" });
    throw new Error(`Unexpected request: ${url}`);
  };
  const login = await service.logIn("student@fit.edu.ph", "private-password");
  assert.equal(login.ok, true);
  assert.equal(login.data.verificationRequired, true);
  assert.equal(service.hasSession(), false);
  const verified = await service.verify("challenge-1", "123456");
  assert.equal(verified.ok, true);
  assert.equal(verified.data.role, "STUDENT");
  assert.equal(service.hasSession(), true);
  assert.deepEqual(paths, ["/stockroom-api/auth/login", "/stockroom-api/auth/verify", "/stockroom-api/me"]);
});

test("admin inventory update sends the real product ID and values", async () => {
  globalThis.fetch = async (url, options) => {
    assert.equal(url, "https://pns-sysnnova.cloud/stockroom-api/equipment/CAM-001");
    assert.equal(options.method, "PATCH");
    assert.deepEqual(JSON.parse(options.body), {
      id: "CAM-001", name: "Camera", category: "Video", description: "HD camera",
      min_stock: 2, archived: false,
    });
    return reply({ id: "CAM-001", name: "Camera", category: "Video", description: "HD camera", min_stock: 2, archived: false, total: 3, available: 2 });
  };
  const response = await service.saveProduct({ id: "CAM-001", equipmentId: "CAM-001", name: "Camera", category: "Video", description: "HD camera", minimumStockLevel: 2 });
  assert.equal(response.ok, true);
  assert.equal(response.data.availableUnits, 2);
  service.clearSession();
});
