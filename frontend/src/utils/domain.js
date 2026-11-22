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
export const schoolEmail = (value) => {
  const email = value.trim().toLowerCase();
  const separator = email.lastIndexOf("@");
  if (separator <= 0 || separator !== email.indexOf("@")) return false;
  const local = email.slice(0, separator);
  const domain = email.slice(separator + 1);
  return /^[a-z0-9](?:[a-z0-9._%+-]*[a-z0-9])?$/.test(local) &&
    SCHOOL_DOMAINS.some((allowed) => domain === allowed.toLowerCase());
};
export const number = (value) => Number(value).toLocaleString("en-PH");
export const productOf = (unit, products) =>
  products.find((item) => item.id === unit?.productId);
export const unitOf = (loan, units) =>
  units.find((item) => item.id === loan?.unitId);
export const isOverdue = (loan) =>
  loan.status === "ACTIVE" && new Date(loan.expectedReturnAt) < new Date();
