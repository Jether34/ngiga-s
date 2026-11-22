import {
  loans,
  products,
  receipts,
  transactions,
  units,
  users,
} from "../data/fixtures";

const pause = () => new Promise((resolve) => setTimeout(resolve, 260));
const copy = (value) => structuredClone(value);
const result = (data) => ({ ok: true, data: copy(data), mode: "demo" });
const failure = (code, message) => ({
  ok: false,
  error: { code, message },
  mode: "demo",
});

// These functions are the frontend integration seam. Replace their bodies with API
// requests; keep the result shape so page states continue to work.
export const demoService = {
  async currentUser(id) {
    await pause();
    return result(users.find((user) => user.id === id) || null);
  },
  async logIn(email, password) {
    await pause();
    const user = users.find(
      (item) => item.schoolEmail.toLowerCase() === email.toLowerCase(),
    );
    return user && password === "Demo123!"
      ? result(user)
      : failure(
          "INVALID_CREDENTIALS",
          "We could not sign you in. Check your school email and password.",
        );
  },
  async signUp(payload) {
    await pause();
    const { fullName, studentId, schoolEmail, yearLevel, program, address } = payload;
    return result({ fullName, studentId, schoolEmail, yearLevel, program, address, id: "demo-new", role: "STUDENT" });
  },
  async logOut() {
    await pause();
    return result(true);
  },
  async listProducts() {
    await pause();
    return result(products);
  },
  async productDetail(id) {
    await pause();
    return result(products.find((item) => item.id === id) || null);
  },
  async listUnits() {
    await pause();
    return result(units);
  },
  async lookupUnit(code) {
    await pause();
    const unit = units.find(
      (item) => item.itemCode.toLowerCase() === code.trim().toLowerCase(),
    );
    return unit
      ? result(unit)
      : failure(
          "NOT_FOUND",
          "No physical unit matches this code. Check the label and try again.",
        );
  },
  async listLoans() {
    await pause();
    return result(loans);
  },
  async listTransactions() {
    await pause();
    return result(transactions);
  },
  async listStudents() {
    await pause();
    return result(users.filter((item) => item.role === "STUDENT"));
  },
  async receiptFor(loanId) {
    await pause();
    return result(receipts.find((item) => item.loanId === loanId) || null);
  },
  async lowStockReport() {
    await pause();
    return result(
      products.filter(
        (item) =>
          !item.archived && item.availableUnits <= item.minimumStockLevel,
      ),
    );
  },
  async borrow() {
    await pause();
    return result({
      reference: "PREVIEW-LOAN",
      receiptStatus: "NOT_GENERATED",
      persisted: false,
    });
  },
  async adminIssue() {
    await pause();
    return result({ reference: "PREVIEW-ISSUE", persisted: false });
  },
  async adminReturn() {
    await pause();
    return result({ reference: "PREVIEW-RETURN", persisted: false });
  },
  async receiveUnit() {
    await pause();
    return result({ persisted: false });
  },
  async saveProfile() {
    await pause();
    return result({ persisted: false });
  },
  async saveProduct() {
    await pause();
    return result({ persisted: false });
  },
  async setStudentStatus() {
    await pause();
    return result({ persisted: false });
  },
  subscribe() {
    return () => {};
  },
};
