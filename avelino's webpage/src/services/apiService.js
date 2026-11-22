const TOKEN_KEY = "encore-web-token";
const USER_KEY = "encore-web-user";
const API_ROOT = "https://pns-sysnnova.cloud/stockroom-api";

let students = [];
let receiptRows = [];

const stored = (key) => {
  try { return sessionStorage.getItem(key); } catch { return null; }
};
const save = (key, value) => {
  try { sessionStorage.setItem(key, value); } catch { /* A private browser may block storage. */ }
};
const remove = (key) => {
  try { sessionStorage.removeItem(key); } catch { /* Ignore unavailable storage. */ }
};

export const storedUser = () => {
  try { return JSON.parse(stored(USER_KEY) || "null"); } catch { return null; }
};
export const hasSession = () => Boolean(stored(TOKEN_KEY));
export const clearSession = () => {
  remove(TOKEN_KEY);
  remove(USER_KEY);
  students = [];
  receiptRows = [];
};

async function request(path, { method = "GET", body } = {}) {
  const headers = { Accept: "application/json" };
  const token = stored(TOKEN_KEY);
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const response = await fetch(`${API_ROOT}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: "no-store",
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 && token) clearSession();
    throw new Error(data.detail || `Request failed (${response.status}).`);
  }
  return data;
}

const result = (data) => ({ ok: true, data });
const guard = async (callback) => {
  try { return result(await callback()); }
  catch (error) { return { ok: false, error: { message: error.message || "Request failed." } }; }
};

const mapUser = (row) => ({
  id: row.id,
  role: row.role,
  fullName: row.name,
  studentId: row.account_id,
  schoolEmail: row.email,
  phone: row.phone || "",
  program: row.program || "",
  yearLevel: row.year_level || "",
  section: row.section || "",
  address: row.home_address || "",
  accountStatus: row.account_status === "SUSPENDED" ? "Suspended" : "Active",
});
const mapProduct = (row) => ({
  id: row.id,
  equipmentId: row.id,
  name: row.name,
  category: row.category,
  description: row.description || "",
  minimumStockLevel: Number(row.min_stock || 0),
  totalUnits: Number(row.total || 0),
  availableUnits: Number(row.available || 0),
  archived: Boolean(row.archived),
  image: row.image || "",
  icon: "generic",
});
const mapUnit = (row) => ({
  id: row.id || row.unit_id,
  productId: row.equipment_id,
  itemCode: row.serial,
  serialNumber: row.manufacturer_serial || row.serial,
  status: row.status === "ISSUED" ? "BORROWED" : row.status,
  receivedAt: row.received_at || "",
});
const studentFor = (row) => students.find((user) => user.studentId === row.borrower_id);
const mapLoan = (row) => ({
  id: row.loan_id,
  loanNumber: row.receipt_number,
  studentId: studentFor(row)?.id || (storedUser()?.studentId === row.borrower_id ? storedUser()?.id : row.borrower_id),
  unitId: row.unit_record_id,
  borrowedAt: row.borrowed_at,
  expectedReturnAt: row.due_at,
  actualReturnAt: row.returned_at || null,
  status: row.loan_status === "RETURNED" ? "RETURNED" : "ACTIVE",
  issuedBy: null,
});
const mapReceipt = (row) => ({
  loanId: row.loan_id,
  receiptNumber: row.receipt_number,
  renderStatus: "READY",
  emailStatus: "UNKNOWN",
  pdfUrl: null,
  pngUrl: null,
  sentAt: row.borrowed_at,
});
async function rememberSession(payload) {
  save(TOKEN_KEY, payload.token);
  try {
    const user = mapUser(await request("/me"));
    save(USER_KEY, JSON.stringify(user));
    return user;
  } catch (error) {
    clearSession();
    throw error;
  }
}

export const apiService = {
  clearSession,
  storedUser,
  hasSession,
  currentUser: () => guard(async () => {
    if (!hasSession()) throw new Error("Sign in required.");
    const user = mapUser(await request("/me"));
    save(USER_KEY, JSON.stringify(user));
    return user;
  }),
  logIn: (email, password) => guard(async () => {
    const payload = await request("/auth/login", { method: "POST", body: { email, password } });
    if (payload.verification_required) return {
      verificationRequired: true,
      challengeId: payload.challenge_id,
      email: payload.email,
    };
    return rememberSession(payload);
  }),
  signUp: (form) => guard(async () => {
    const payload = await request("/auth/signup", {
      method: "POST",
      body: {
        name: form.fullName,
        student_id: form.studentId,
        email: form.schoolEmail,
        phone: form.phone,
        year_level: form.yearLevel,
        program: form.program,
        section: form.section,
        home_address: form.address,
        password: form.password,
        agree_terms: true,
      },
    });
    return { verificationRequired: true, challengeId: payload.challenge_id, email: payload.email };
  }),
  verify: (challengeId, code) => guard(async () =>
    rememberSession(await request("/auth/verify", {
      method: "POST", body: { challenge_id: challengeId, code },
    }))),
  requestPasswordReset: (email) => guard(() => request("/auth/password-reset/request", {
    method: "POST", body: { email },
  })),
  logOut: async () => { clearSession(); return result(true); },
  listProducts: () => guard(async () => (await request("/equipment")).map(mapProduct)),
  productDetail: (id) => guard(async () => mapProduct(await request(`/equipment/${encodeURIComponent(id)}`))),
  listUnits: () => guard(async () => (await request("/units")).map(mapUnit)),
  lookupUnit: (code) => guard(async () => mapUnit(await request(`/units/${encodeURIComponent(code.trim())}`))),
  listStudents: () => guard(async () => {
    students = (await request("/students")).map(mapUser);
    return students;
  }),
  listLoans: () => guard(async () => {
    receiptRows = await request("/receipts");
    return receiptRows.map(mapLoan);
  }),
  listReceipts: () => guard(async () => {
    receiptRows = await request("/receipts");
    return receiptRows.map(mapReceipt);
  }),
  receiptFor: (loanId) => guard(async () => {
    if (!receiptRows.length) receiptRows = await request("/receipts");
    return mapReceipt(receiptRows.find((row) => row.loan_id === loanId));
  }),
  listTransactions: () => guard(async () => {
    if (storedUser()?.role !== "ADMIN") return receiptRows.flatMap((row) => [
      {
        id: `borrow-${row.loan_id}`, type: "ISSUE", unitId: row.unit_record_id,
        studentId: storedUser()?.id, operatorId: null, loanId: row.loan_id,
        timestamp: row.borrowed_at, remarks: "",
      },
      ...(row.returned_at ? [{
        id: `return-${row.loan_id}`, type: "RETURN", unitId: row.unit_record_id,
        studentId: storedUser()?.id, operatorId: null, loanId: row.loan_id,
        timestamp: row.returned_at, remarks: "",
      }] : []),
    ]);
    const rows = await request("/transactions");
    return rows.map((row) => {
      const loan = receiptRows.find((item) => item.loan_id === row.loan_id);
      return {
        id: row.id,
        type: row.type === "RECEIVE" && row.loan_id ? "RETURN" : row.type,
        unitId: row.unit_id,
        studentId: loan ? studentFor(loan)?.id || null : null,
        operatorId: row.actor_id,
        loanId: row.loan_id,
        timestamp: row.created_at,
        remarks: "",
      };
    });
  }),
  lowStockReport: () => guard(async () => (await request("/reports/low-stock")).map(mapProduct)),
  borrow: ({ unitId, dueAt, borrowerId } = {}) => guard(async () => {
    const body = {
      unit_id: unitId,
      due_at: new Date(dueAt).toISOString(),
      idempotency_key: crypto.randomUUID(),
    };
    if (borrowerId) body.borrower_id = borrowerId;
    const receipt = await request("/loans", { method: "POST", body });
    receiptRows.unshift(receipt);
    return receipt;
  }),
  adminIssue: (payload) => apiService.borrow(payload),
  adminReturn: ({ itemCode, returnedAt, condition }) => guard(() => request(`/returns/${encodeURIComponent(itemCode)}`, {
    method: "POST",
    body: { returned_at: new Date(returnedAt).toISOString(), condition: condition === "Good" ? "GOOD" : "MAINTENANCE" },
  })),
  receiveUnit: ({ productId, itemCode, serialNumber, receivedAt }) => guard(async () => mapUnit(
    await request(`/equipment/${encodeURIComponent(productId)}/units`, {
      method: "POST",
      body: { serial: itemCode, manufacturer_serial: serialNumber, received_at: receivedAt },
    }),
  )),
  saveProfile: (form) => guard(async () => {
    const user = mapUser(await request("/me", {
      method: "PATCH",
      body: {
        name: form.fullName,
        email: form.schoolEmail,
        phone: form.phone,
        section: form.section,
        home_address: form.address,
        student_id: form.studentId,
        year_level: form.yearLevel,
        program: form.program,
      },
    }));
    save(USER_KEY, JSON.stringify(user));
    return user;
  }),
  saveProduct: (item) => guard(async () => mapProduct(await request(
    item.id ? `/equipment/${encodeURIComponent(item.id)}` : "/equipment",
    {
      method: item.id ? "PATCH" : "POST",
      body: {
        id: item.equipmentId,
        name: item.name,
        category: item.category,
        description: item.description,
        min_stock: Number(item.minimumStockLevel),
        archived: Boolean(item.archived),
      },
    },
  ))),
  setStudentStatus: (id, status) => guard(() => request(
    `/students/${encodeURIComponent(id)}/status`,
    { method: "PATCH", body: { status: status.toUpperCase() } },
  )),
  saveAvatar: (dataUrl) => guard(() => request("/me/avatar", {
    method: "PATCH", body: { image: dataUrl.split(",")[1] || "" },
  })),
  getAvatar: () => guard(async () => {
    const response = await request("/me/avatar");
    if (!response.image) return "";
    return `data:image/jpeg;base64,${response.image}`;
  }),
  changePassword: (current, next) => guard(() => request("/me/password", {
    method: "POST", body: { current_password: current, new_password: next },
  })),
  subscribe: () => () => {},
};
