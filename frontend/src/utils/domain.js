import {
  House,
  Package,
  ScanLine,
  History,
  Users,
  Settings,
} from "lucide-react";
import { SCHOOL_DOMAINS } from "../data/fixtures";

export const studentLinks = [
  ["Home", House],
  ["Scan", ScanLine],
  ["History", History],
  ["Settings", Settings],
];
export const adminLinks = [
  ["Home", House],
  ["Products", Package],
  ["Scan", ScanLine],
  ["History", History],
  ["Users", Users],
  ["Settings", Settings],
];
export const pretty = (value) =>
  value
    ? new Date(value).toLocaleString("en-PH", {
        dateStyle: "medium",
        timeStyle: "short",
      })
    : "—";
export const dateInput = (value) => {
  const d = value ? new Date(value) : new Date();
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
};
export const schoolEmail = (value) =>
  SCHOOL_DOMAINS.some((domain) =>
    value.trim().toLowerCase().endsWith(`@${domain}`),
  );
export const number = (value) => Number(value).toLocaleString("en-PH");
export const productOf = (unit, products) =>
  products.find((item) => item.id === unit?.productId);
export const unitOf = (loan, units) =>
  units.find((item) => item.id === loan?.unitId);
export const isOverdue = (loan) =>
  loan.status === "ACTIVE" && new Date(loan.expectedReturnAt) < new Date();
