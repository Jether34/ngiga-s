import { useRef, useState } from "react";
import {
  Package,
  ScanLine,
  History,
  LogOut,
  CircleUserRound,
  Search,
  CalendarDays,
  Download,
  RotateCcw,
  ArrowRight,
  ChevronRight,
  Check,
  AlertCircle,
  PackageCheck,
  ClockAlert,
  SlidersHorizontal,
  QrCode,
  RefreshCw,
  LockKeyhole,
} from "lucide-react";
import { receipts } from "../data/fixtures";
import { demoService } from "../services/demoService";
import {
  Badge,
  Empty,
  Field,
  Modal,
  PageHead,
  DemoNote,
  ProductArt,
  ProductCard,
  StatCard,
  Loading,
} from "../components/ui";
import {
  pretty,
  dateInput,
  productOf,
  unitOf,
  isOverdue,
} from "../utils/domain";
import { ProductDetail } from "../components/ProductDetail";
import { ScanCapture } from "../components/ScanCapture";

export function StudentHome({
  session,
  products,
  units,
  loans,
  transactions,
  navigate,
  refresh,
  loading,
  dataError,
}) {
  const [search, setSearch] = useState("");
  const searchInputRef = useRef(null);
  const [category, setCategory] = useState("All");
  const [selected, setSelected] = useState(null);
  const categories = ["All", ...new Set(products.map((item) => item.category))];
  const shown = products.filter(
    (item) =>
      !item.archived &&
      (category === "All" || item.category === category) &&
      `${item.name} ${item.description} ${item.equipmentId}`
        .toLowerCase()
        .includes(search.toLowerCase()),
  );
  const mine = loans.filter((loan) => loan.studentId === session.id);
  const active = mine.filter((loan) => loan.status === "ACTIVE");
  const recent = transactions
    .filter((tx) => tx.studentId === session.id)
    .slice(0, 3);
  return (
    <>
      <div className="student-hero">
        <div>
          <span className="eyebrow">YOUR EQUIPMENT WORKSPACE</span>
          <h1>
            Good day, {session.fullName.split(" ")[0]} <span>✳</span>
          </h1>
          <p>
            Find the tools for your next project and keep track of everything
            you've borrowed.
          </p>
          <button className="button" onClick={() => navigate("/student/scan")}>
            Scan equipment <ScanLine size={18} />
          </button>
        </div>
        <div className="hero-decoration">
          <div className="hero-decoration-inner">
            <PackageCheck size={82} strokeWidth={1.15} />
          </div>
        </div>
      </div>
      <DemoNote />
      <div className="stats-grid student-stats">
        <StatCard
          icon={Package}
          label="Active loans"
          value={active.length}
          sub="Currently in your care"
        />
        <StatCard
          icon={CalendarDays}
          label="Upcoming returns"
          value={active.filter((item) => !isOverdue(item)).length}
          sub="Keep an eye on due dates"
          tone="blue"
        />
        <StatCard
          icon={ClockAlert}
          label="Overdue items"
          value={active.filter(isOverdue).length}
          sub="Please return promptly"
          tone="red"
        />
      </div>
      {active.some(isOverdue) && (
        <div className="callout danger-callout">
          <ClockAlert size={20} />
          <span>
            <strong>Return attention needed</strong>
            <br />
            One or more items are past their due time.
          </span>
          <button onClick={() => navigate("/student/history")}>
            View loans <ArrowRight size={16} />
          </button>
        </div>
      )}
      <div className="section-heading catalog-heading">
        <div>
          <span className="eyebrow">EXPLORE THE CATALOG</span>
          <h2>Find your equipment</h2>
        </div>
        <div className="action-row catalog-actions">
          <button className="text-button" onClick={refresh} disabled={loading}>
            <RefreshCw size={15} className={loading ? "spin" : ""} /> Refresh
          </button>
          <button
            className="text-button"
            onClick={() => navigate("/student/scan")}
          >
            Have a code? Scan it <ArrowRight size={16} />
          </button>
        </div>
      </div>
      <div className="catalog-controls">
        <div className="search-box catalog-search">
          <button
            type="button"
            className="catalog-search-trigger"
            aria-label="Focus equipment search"
            onClick={() => searchInputRef.current?.focus()}
          >
            <Search size={18} aria-hidden="true" />
          </button>
          <input
            ref={searchInputRef}
            type="search"
            aria-label="Search equipment, category, or ID"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search equipment, category, or ID"
          />
        </div>
        <div className="chips" aria-label="Categories">
          {categories.map((item) => (
            <button
              key={item}
              className={`chip ${item === category ? "selected" : ""}`}
              aria-pressed={item === category}
              onClick={() => setCategory(item)}
            >
              {item}
            </button>
          ))}
        </div>
      </div>
      {loading ? (
        <Loading />
      ) : dataError ? (
        <div className="inline-error">
          <AlertCircle size={17} />
          {dataError} <button onClick={refresh}>Retry</button>
        </div>
      ) : shown.length ? (
        <div className="product-grid">
          {shown.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              onOpen={setSelected}
            />
          ))}
        </div>
      ) : (
        <Empty
          icon={Search}
          title="No equipment found"
          text="Try another search or category."
        />
      )}
      <div className="home-lower">
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">YOUR LOANS</span>
              <h2>Borrowed right now</h2>
            </div>
            <button
              className="text-button"
              onClick={() => navigate("/student/history")}
            >
              View all <ArrowRight size={16} />
            </button>
          </div>
          {active.length ? (
            active.map((loan) => {
              const unit = unitOf(loan, units),
                product = productOf(unit, products);
              return (
                <div className="loan-mini" key={loan.id}>
                  <ProductArt product={product} />
                  <div>
                    <strong>{product?.name}</strong>
                    <small>{unit?.itemCode}</small>
                  </div>
                  <div className="loan-mini-due">
                    <Badge tone={isOverdue(loan) ? "danger" : "warning"}>
                      {isOverdue(loan) ? "Overdue" : "Active"}
                    </Badge>
                    <small>Due {pretty(loan.expectedReturnAt)}</small>
                  </div>
                </div>
              );
            })
          ) : (
            <Empty
              title="No active loans"
              text="Scan an available item to start a borrowing review."
            />
          )}
        </section>
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">LATEST UPDATES</span>
              <h2>Recent activity</h2>
            </div>
          </div>
          {recent.length ? (
            recent.map((tx) => {
              const product = productOf(
                units.find((unit) => unit.id === tx.unitId),
                products,
              );
              return (
                <div className="activity-row" key={tx.id}>
                  <span className={`activity-icon ${tx.type.toLowerCase()}`}>
                    {tx.type === "RETURN" ? (
                      <RotateCcw size={18} />
                    ) : (
                      <PackageCheck size={18} />
                    )}
                  </span>
                  <div>
                    <strong>
                      {tx.type === "RETURN" ? "Returned" : "Borrowed"}{" "}
                      {product?.name}
                    </strong>
                    <small>{pretty(tx.timestamp)}</small>
                  </div>
                </div>
              );
            })
          ) : (
            <Empty title="No recent activity" />
          )}
        </section>
      </div>
      {selected && (
        <ProductDetail
          product={selected}
          units={units}
          onClose={() => setSelected(null)}
          navigate={navigate}
        />
      )}
    </>
  );
}

export function StudentScan({ session, products }) {
  const [unit, setUnit] = useState(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [due, setDue] = useState(""),
    [step, setStep] = useState("capture"),
    [borrowAt, setBorrowAt] = useState(null);
  const lookup = async (code) => {
    setBusy(true);
    setError("");
    setUnit(null);
    const response = await demoService.lookupUnit(code);
    setBusy(false);
    if (response.ok) {
      setUnit(response.data);
      setStep("result");
    } else setError(response.error.message);
  };
  const product = productOf(unit, products);
  const review = () => {
    const now = new Date();
    if (!due || isNaN(new Date(due)) || new Date(due) <= now) {
      setError(
        "Choose a valid return date and time later than the borrowing time.",
      );
      return;
    }
    setBorrowAt(now.toISOString());
    setError("");
    setStep("review");
  };
  const confirm = async () => {
    setBusy(true);
    const response = await demoService.borrow();
    setBusy(false);
    if (response.ok) setStep("done");
    else {
      setError(response.error.message);
      setStep("result");
    }
  };
  const reset = () => {
    setUnit(null);
    setDue("");
    setError("");
    setStep("capture");
  };
  return (
    <>
      <PageHead
        eyebrow="STUDENT / SCAN"
        title="Scan equipment"
        description="Capture the exact physical unit before reviewing your loan."
      />
      <DemoNote>
        Demo scan lookup uses fixture codes such as CAM-R50-001. Confirmations
        are previews only; no loan or receipt is saved.
      </DemoNote>
      <div className="scan-layout">
        <div className="panel scan-panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">STEP 01</span>
              <h2>Identify the unit</h2>
            </div>
            <Badge tone="warning">Camera or manual</Badge>
          </div>
          <ScanCapture onCode={lookup} />
          {busy && <Loading />}
          {error && (
            <div className="inline-error">
              <AlertCircle size={17} />
              {error}
            </div>
          )}
        </div>
        <div className="panel scan-result-panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">
                {step === "review" ? "STEP 03" : "STEP 02"}
              </span>
              <h2>{step === "review" ? "Review loan" : "Item details"}</h2>
            </div>
          </div>
          {!unit ? (
            <Empty
              icon={QrCode}
              title="Your scan result appears here"
              text="Use the camera or enter an item code to identify a specific physical unit."
            />
          ) : step === "done" ? (
            <div className="result-success">
              <span className="success-emblem">
                <Check size={30} />
              </span>
              <h3>Review completed</h3>
              <p>
                This was a demo confirmation. No loan was saved and no receipt
                was generated or emailed.
              </p>
              <div className="reference-line">
                Preview reference <strong>PREVIEW-LOAN</strong>
              </div>
              <button className="button wide" onClick={reset}>
                Scan another item
              </button>
            </div>
          ) : (
            <>
              <div className="exact-item">
                <ProductArt product={product} />
                <div>
                  <span className="eyebrow">{product?.category}</span>
                  <h3>{product?.name}</h3>
                  <p>{product?.description}</p>
                </div>
              </div>
              <div className="details-list">
                <div>
                  <span>Item code</span>
                  <strong>{unit.itemCode}</strong>
                </div>
                <div>
                  <span>Serial number</span>
                  <strong>{unit.serialNumber}</strong>
                </div>
                <div>
                  <span>Unit status</span>
                  <Badge
                    tone={
                      unit.status === "AVAILABLE"
                        ? "success"
                        : unit.status === "BORROWED"
                          ? "warning"
                          : "danger"
                    }
                  >
                    {unit.status === "AVAILABLE"
                      ? "Available"
                      : unit.status === "BORROWED"
                        ? "Borrowed"
                        : "Maintenance"}
                  </Badge>
                </div>
              </div>
              {unit.status !== "AVAILABLE" ? (
                <div className="callout danger-callout">
                  <AlertCircle size={19} />
                  This exact unit is {unit.status.toLowerCase()} and cannot be
                  borrowed. Scan another unit.
                </div>
              ) : step === "review" ? (
                <>
                  <div className="review-box">
                    <h3>Borrowing summary</h3>
                    <div>
                      <span>Student</span>
                      <strong>{session.fullName}</strong>
                    </div>
                    <div>
                      <span>Student ID</span>
                      <strong>{session.studentId}</strong>
                    </div>
                    <div>
                      <span>Product</span>
                      <strong>
                        {product?.name} · {product?.category}
                      </strong>
                    </div>
                    <div>
                      <span>Exact unit</span>
                      <strong>
                        {unit.itemCode} · {unit.serialNumber}
                      </strong>
                    </div>
                    <div>
                      <span>Borrowing time</span>
                      <strong>{pretty(borrowAt)}</strong>
                    </div>
                    <div>
                      <span>Expected return</span>
                      <strong>{pretty(due)}</strong>
                    </div>
                  </div>
                  <p className="fine-print">
                    Availability and policy are checked by the server when an
                    API is connected.
                  </p>
                  <div className="action-row">
                    <button
                      className="button secondary"
                      onClick={() => setStep("result")}
                    >
                      Back
                    </button>
                    <button
                      className="button"
                      onClick={confirm}
                      disabled={busy}
                    >
                      {busy ? "Reviewing…" : "Confirm demo loan"}{" "}
                      <Check size={17} />
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <Field label="Expected return date and time" required>
                    <input
                      type="datetime-local"
                      value={due}
                      min={dateInput()}
                      onChange={(event) => {
                        setDue(event.target.value);
                        setError("");
                      }}
                    />
                  </Field>
                  <button className="button wide" onClick={review}>
                    Review borrowing <ArrowRight size={17} />
                  </button>
                </>
              )}
            </>
          )}
        </div>
      </div>
    </>
  );
}

export function StudentHistory({ session, loans, units, products }) {
  const [filter, setFilter] = useState("All"),
    [selected, setSelected] = useState(null);
  const mine = loans.filter((loan) => loan.studentId === session.id);
  const shown = mine.filter(
    (loan) =>
      filter === "All" ||
      (filter === "Overdue"
        ? isOverdue(loan)
        : loan.status === filter.toUpperCase() && !isOverdue(loan)),
  );
  return (
    <>
      <PageHead
        eyebrow="STUDENT / HISTORY"
        title="Borrowing history"
        description="A clear record of your equipment and return dates."
      />
      <DemoNote>
        History is limited to the current demo student. Receipt downloads
        require actual artifact URLs from a future receipt service.
      </DemoNote>
      <div className="history-summary">
        <StatCard
          icon={PackageCheck}
          label="Active"
          value={mine.filter((x) => x.status === "ACTIVE").length}
        />
        <StatCard
          icon={RotateCcw}
          label="Returned"
          value={mine.filter((x) => x.status === "RETURNED").length}
          tone="blue"
        />
        <StatCard
          icon={ClockAlert}
          label="Overdue"
          value={mine.filter(isOverdue).length}
          tone="red"
        />
      </div>
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">YOUR RECORDS</span>
            <h2>All loans</h2>
          </div>
          <div className="chips">
            {["All", "Active", "Returned", "Overdue"].map((x) => (
              <button
                key={x}
                className={`chip ${filter === x ? "selected" : ""}`}
                onClick={() => setFilter(x)}
              >
                {x}
              </button>
            ))}
          </div>
        </div>
        {shown.length ? (
          <div className="loan-list">
            {shown.map((loan) => {
              const unit = unitOf(loan, units),
                product = productOf(unit, products),
                receipt = receipts.find((x) => x.loanId === loan.id);
              return (
                <button
                  className="loan-card"
                  key={loan.id}
                  onClick={() => setSelected(loan)}
                >
                  <ProductArt product={product} />
                  <div className="loan-card-main">
                    <strong>{product?.name}</strong>
                    <small>
                      {loan.loanNumber} · {unit?.itemCode}
                    </small>
                    <span>Due {pretty(loan.expectedReturnAt)}</span>
                  </div>
                  <div className="loan-card-right">
                    <Badge
                      tone={
                        isOverdue(loan)
                          ? "danger"
                          : loan.status === "RETURNED"
                            ? "success"
                            : "warning"
                      }
                    >
                      {isOverdue(loan)
                        ? "Overdue"
                        : loan.status === "RETURNED"
                          ? "Returned"
                          : "Active"}
                    </Badge>
                    <small>
                      Receipt:{" "}
                      {receipt?.renderStatus === "READY"
                        ? "Ready, file unavailable"
                        : receipt?.renderStatus === "PENDING"
                          ? "Pending"
                          : "Not generated"}
                    </small>
                  </div>
                  <ChevronRight size={18} />
                </button>
              );
            })}
          </div>
        ) : (
          <Empty
            icon={History}
            title="No matching loans"
            text="Try another status filter."
          />
        )}
      </div>
      {selected &&
        (() => {
          const unit = unitOf(selected, units),
            product = productOf(unit, products),
            receipt = receipts.find((x) => x.loanId === selected.id);
          return (
            <Modal title="Loan details" onClose={() => setSelected(null)}>
              <div className="exact-item">
                <ProductArt product={product} />
                <div>
                  <span className="eyebrow">{selected.loanNumber}</span>
                  <h3>{product?.name}</h3>
                  <span className="muted">
                    {unit?.itemCode} · Serial {unit?.serialNumber}
                  </span>
                </div>
              </div>
              <div className="details-list">
                <div>
                  <span>Borrowed</span>
                  <strong>{pretty(selected.borrowedAt)}</strong>
                </div>
                <div>
                  <span>Expected return</span>
                  <strong>{pretty(selected.expectedReturnAt)}</strong>
                </div>
                <div>
                  <span>Actual return</span>
                  <strong>{pretty(selected.actualReturnAt)}</strong>
                </div>
                <div>
                  <span>Status</span>
                  <Badge
                    tone={
                      isOverdue(selected)
                        ? "danger"
                        : selected.status === "RETURNED"
                          ? "success"
                          : "warning"
                    }
                  >
                    {isOverdue(selected)
                      ? "Overdue"
                      : selected.status === "RETURNED"
                        ? "Returned"
                        : "Active"}
                  </Badge>
                </div>
                <div>
                  <span>Receipt</span>
                  <strong>
                    {receipt?.renderStatus === "PENDING"
                      ? "Pending"
                      : receipt?.renderStatus === "READY"
                        ? "Ready, artifact unavailable"
                        : "Not generated"}
                  </strong>
                </div>
                <div>
                  <span>Email delivery</span>
                  <strong>Not sent (demo)</strong>
                </div>
              </div>
              <div className="receipt-actions">
                <button
                  className="button secondary"
                  disabled={!receipt?.pdfUrl}
                  onClick={() =>
                    window.open(receipt.pdfUrl, "_blank", "noopener,noreferrer")
                  }
                >
                  <Download size={17} /> PDF receipt
                </button>
                <button
                  className="button secondary"
                  disabled={!receipt?.pngUrl}
                  onClick={() =>
                    window.open(receipt.pngUrl, "_blank", "noopener,noreferrer")
                  }
                >
                  <Download size={17} /> PNG receipt
                </button>
              </div>
              <p className="fine-print">
                Downloads activate only when the receipt service supplies files.
              </p>
            </Modal>
          );
        })()}
    </>
  );
}

export function SettingsPage({ session, role, logout, notify }) {
  const [form, setForm] = useState({
    fullName: session.fullName,
    program: session.program || "",
    yearLevel: session.yearLevel || "",
    address: session.address || "",
  });
  const [password, setPassword] = useState({
    current: "",
    next: "",
    confirm: "",
  });
  const [preferences, setPreferences] = useState({
    lowStock: true,
    overdue: true,
    summary: false,
  });
  const [error, setError] = useState("");
  const save = async (event) => {
    event.preventDefault();
    if (
      form.fullName.trim().length < 2 ||
      !form.program.trim() ||
      form.address.trim().length < 8 ||
      (role === "STUDENT" && !form.yearLevel)
    ) {
      setError("Complete your name, program, year level, and address.");
      return;
    }
    setError("");
    await demoService.saveProfile(form);
    notify("Profile preview validated. Connect a profile API to save changes.");
  };
  const changePassword = (event) => {
    event.preventDefault();
    if (
      !password.current ||
      !/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/.test(password.next) ||
      password.next !== password.confirm
    ) {
      notify(
        "Check your current password, password rules, and confirmation.",
        "error",
      );
      return;
    }
    notify(
      "Password form validated. Connect an identity service to change it.",
    );
    setPassword({ current: "", next: "", confirm: "" });
  };
  return (
    <>
      <PageHead
        eyebrow={`${role} / SETTINGS`}
        title="Account settings"
        description="Review your profile, security, and preferences."
      />
      <DemoNote>
        Profile and security changes are validated locally. They require a
        connected account service to persist.
      </DemoNote>
      <div className="settings-grid">
        <div className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">PROFILE</span>
              <h2>Personal information</h2>
            </div>
            <CircleUserRound size={22} />
          </div>
          <form onSubmit={save}>
            <div className="form-grid">
              <Field label="Full name" required>
                <input
                  value={form.fullName}
                  onChange={(e) =>
                    setForm({ ...form, fullName: e.target.value })
                  }
                />
              </Field>
              <Field
                label="School email"
                hint="Changes require an authorized identity process."
              >
                <input value={session.schoolEmail} readOnly />
              </Field>
            </div>
            {role === "STUDENT" && (
              <div className="form-grid">
                <Field
                  label="Student ID"
                  hint="Student ID cannot be self-edited."
                >
                  <input value={session.studentId || ""} readOnly />
                </Field>
                <Field label="Year level" required>
                  <select
                    value={form.yearLevel}
                    onChange={(e) =>
                      setForm({ ...form, yearLevel: e.target.value })
                    }
                  >
                    {[
                      "1st Year",
                      "2nd Year",
                      "3rd Year",
                      "4th Year",
                      "5th Year",
                      "Graduate",
                    ].map((x) => (
                      <option key={x}>{x}</option>
                    ))}
                  </select>
                </Field>
              </div>
            )}
            <Field
              label={role === "ADMIN" ? "Department" : "Academic program"}
              required
            >
              <input
                value={form.program}
                onChange={(e) => setForm({ ...form, program: e.target.value })}
              />
            </Field>
            <Field label="Complete address" required>
              <textarea
                rows="3"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </Field>
            {error && (
              <div className="inline-error">
                <AlertCircle size={17} />
                {error}
              </div>
            )}
            <button className="button">
              Validate profile changes <Check size={17} />
            </button>
          </form>
        </div>
        <div className="settings-side">
          <div className="panel">
            <div className="panel-title">
              <div>
                <span className="eyebrow">SECURITY</span>
                <h2>Change password</h2>
              </div>
              <LockKeyhole size={21} />
            </div>
            <form onSubmit={changePassword}>
              <Field label="Current password">
                <input
                  type="password"
                  autoComplete="current-password"
                  value={password.current}
                  onChange={(e) =>
                    setPassword({ ...password, current: e.target.value })
                  }
                />
              </Field>
              <Field
                label="New password"
                hint="8+ characters, upper and lowercase letters, and a number"
              >
                <input
                  type="password"
                  autoComplete="new-password"
                  value={password.next}
                  onChange={(e) =>
                    setPassword({ ...password, next: e.target.value })
                  }
                />
              </Field>
              <Field label="Confirm new password">
                <input
                  type="password"
                  autoComplete="new-password"
                  value={password.confirm}
                  onChange={(e) =>
                    setPassword({ ...password, confirm: e.target.value })
                  }
                />
              </Field>
              <button className="button secondary wide">
                Validate password change
              </button>
            </form>
          </div>
          {role === "ADMIN" && (
            <div className="panel">
              <div className="panel-title">
                <div>
                  <span className="eyebrow">SYSTEM</span>
                  <h2>Demo preferences</h2>
                </div>
                <SlidersHorizontal size={21} />
              </div>
              {[
                ["lowStock", "Low-stock alerts"],
                ["overdue", "Overdue loan alerts"],
                ["summary", "Weekly summary"],
              ].map(([key, label]) => (
                <label className="switch-row" key={key}>
                  <span>{label}</span>
                  <input
                    type="checkbox"
                    checked={preferences[key]}
                    onChange={(e) =>
                      setPreferences({
                        ...preferences,
                        [key]: e.target.checked,
                      })
                    }
                  />
                </label>
              ))}
              <p className="fine-print">
                Preference changes are local to this page.
              </p>
            </div>
          )}
          <div className="panel logout-panel">
            <h3>Sign out</h3>
            <p>End this demo session and return to the welcome screen.</p>
            <button className="button secondary" onClick={logout}>
              <LogOut size={17} /> Log out
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
