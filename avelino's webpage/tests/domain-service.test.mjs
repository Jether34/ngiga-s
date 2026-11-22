import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createServer } from "vite";

let server;
let domain;
let service;
let fixtures;

before(async () => {
  server = await createServer({ server: { middlewareMode: true } });
  domain = await server.ssrLoadModule("/src/utils/domain.js");
  ({ demoService: service } = await server.ssrLoadModule("/src/services/demoService.js"));
  fixtures = await server.ssrLoadModule("/src/data/fixtures.js");
});

after(async () => {
  await server?.close();
});

test("school email requires a local part and an exact allowed domain", () => {
  assert.equal(domain.schoolEmail("alex.rivera@university.edu"), true);
  assert.equal(domain.schoolEmail(" ALEX@UNIVERSITY.EDU "), true);
  assert.equal(domain.schoolEmail("@university.edu"), false);
  assert.equal(domain.schoolEmail("alex@@university.edu"), false);
  assert.equal(domain.schoolEmail("alex@university.edu.attacker.test"), false);
});

test("unit lookup identifies a known unit and rejects an unknown code", async () => {
  const known = await service.lookupUnit(" cam-r50-001 ");
  assert.equal(known.ok, true);
  assert.equal(known.data.itemCode, "CAM-R50-001");
  const missing = await service.lookupUnit("UNKNOWN-UNIT");
  assert.equal(missing.ok, false);
  assert.equal(missing.error.code, "NOT_FOUND");
});

test("sign-up preview does not return password fields", async () => {
  const response = await service.signUp({
    fullName: "Sample Student",
    studentId: "2026-00001",
    schoolEmail: "sample@university.edu",
    yearLevel: "1st Year",
    program: "Engineering",
    address: "Sample campus address",
    password: "Private123",
    confirm: "Private123",
  });
  assert.equal(response.ok, true);
  assert.equal(response.data.role, "STUDENT");
  assert.equal("password" in response.data, false);
  assert.equal("confirm" in response.data, false);
});

test("fixture inventory counts and loan references are consistent", () => {
  const unique = (items) => new Set(items).size === items.length;
  assert.ok(unique(fixtures.units.map((unit) => unit.itemCode)));
  assert.ok(unique(fixtures.units.map((unit) => unit.serialNumber)));
  for (const product of fixtures.products) {
    const matching = fixtures.units.filter((unit) => unit.productId === product.id);
    assert.equal(product.totalUnits, matching.length, product.name);
    assert.equal(product.availableUnits, matching.filter((unit) => unit.status === "AVAILABLE").length, product.name);
  }
  for (const loan of fixtures.loans) {
    assert.ok(fixtures.units.some((unit) => unit.id === loan.unitId), loan.id);
    assert.ok(fixtures.users.some((user) => user.id === loan.studentId), loan.id);
  }
  for (const receipt of fixtures.receipts) {
    assert.ok(fixtures.loans.some((loan) => loan.id === receipt.loanId), receipt.loanId);
  }
});
