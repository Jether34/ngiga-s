import { useEffect, useRef, useState } from "react";
import {
  ScanLine,
  Search,
  Camera,
  ArrowRight,
  ArrowLeft,
  Check,
  AlertCircle,
  PackageCheck,
  Eye,
  EyeOff,
  ShieldCheck,
  Sparkles,
  Boxes,
  QrCode,
  RefreshCw,
  CheckCircle2,
  Info,
} from "lucide-react";
import {
  SCHOOL_DOMAINS,
  SCHOOL_NAME,
  products as fixtureProducts,
} from "../data/fixtures";
import { demoService } from "../services/demoService";
import { IconButton, Field, Modal, ProductArt } from "../components/ui";
import { schoolEmail } from "../utils/domain";

const publicLinks = [
  { label: "Home", path: "/" },
  { label: "About Us", path: "/about" },
  { label: "Contact Us", path: "/contact" },
  { label: "Our Goal", path: "/goal" },
];

const headlineLines = ["Everything you need.", "Ready when you are."];
const headlineCycleMs = 10000;
const headlineStepMs = 55;
const headlinePauseMs = 400;
const headlineFadeStartMs = 9600;
const headlineSecondStartMs = headlineLines[0].length * headlineStepMs + headlinePauseMs;
const headlineFinishMs = headlineSecondStartMs + headlineLines[1].length * headlineStepMs;

function headlineFrame(elapsed) {
  const firstCount = Math.min(headlineLines[0].length, Math.floor(elapsed / headlineStepMs));
  const secondCount = Math.min(
    headlineLines[1].length,
    Math.max(0, Math.floor((elapsed - headlineSecondStartMs) / headlineStepMs)),
  );
  return {
    firstCount,
    secondCount,
    cursorLine: elapsed < headlineLines[0].length * headlineStepMs
      ? 0
      : elapsed >= headlineSecondStartMs && elapsed < headlineFinishMs ? 1 : -1,
    fading: elapsed >= headlineFadeStartMs,
  };
}

export function PublicHeader({ navigate, current = "/" }) {
  return (
    <header className="public-header">
      <button className="brand" onClick={() => navigate("/")} aria-label="equip.campus home">
        <span className="brand-mark"><Boxes size={22} /></span>
        <span>equip<span className="brand-dot">.</span>campus</span>
      </button>
      <nav className="public-nav" aria-label="Public navigation">
        {publicLinks.map(({ label, path }) => (
          <a
            key={path}
            href={path}
            aria-current={current === path ? "page" : undefined}
            onClick={(event) => {
              if (event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey) {
                event.preventDefault();
                navigate(path);
              }
            }}
          >
            {label}
          </a>
        ))}
      </nav>
      <div className="public-actions">
        <button className="text-button" onClick={() => navigate("/login")}>Log in</button>
        <button className="button small" onClick={() => navigate("/signup")}>
          Sign up <ArrowRight size={16} />
        </button>
      </div>
    </header>
  );
}

export function PublicFooter() {
  return (
    <footer className="public-footer">
      © {new Date().getFullYear()} {SCHOOL_NAME} · Student Equipment &amp; Inventory Borrowing
    </footer>
  );
}

function LandingHeadline() {
  const [reducedMotion, setReducedMotion] = useState(
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  const [headline, setHeadline] = useState(() => headlineFrame(0));

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const onChange = () => setReducedMotion(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    if (reducedMotion) return undefined;
    const startedAt = performance.now();
    const tick = () => {
      const next = headlineFrame((performance.now() - startedAt) % headlineCycleMs);
      setHeadline((previous) =>
        previous.firstCount === next.firstCount &&
        previous.secondCount === next.secondCount &&
        previous.cursorLine === next.cursorLine &&
        previous.fading === next.fading ? previous : next,
      );
    };
    tick();
    const timer = window.setInterval(tick, headlineStepMs);
    return () => window.clearInterval(timer);
  }, [reducedMotion]);

  return (
    <h1 className={`welcome-headline${!reducedMotion && headline.fading ? " is-fading" : ""}`} aria-label={headlineLines.join(" ")}>
      <span className="headline-line" aria-hidden="true">
        <span className="headline-reserve">{headlineLines[0]}</span>
        <span className="headline-typed">
          {headlineLines[0].slice(0, reducedMotion ? headlineLines[0].length : headline.firstCount)}
          {!reducedMotion && headline.cursorLine === 0 && <span className="headline-cursor" />}
        </span>
      </span>
      <span className="headline-line" aria-hidden="true">
        <em className="headline-reserve">{headlineLines[1]}</em>
        <em className="headline-typed">
          {headlineLines[1].slice(0, reducedMotion ? headlineLines[1].length : headline.secondCount)}
          {!reducedMotion && headline.cursorLine === 1 && <span className="headline-cursor" />}
        </em>
      </span>
    </h1>
  );
}

export function Welcome({ navigate }) {
  const [selectedVisual, setSelectedVisual] = useState(null);
  const visualRef = useRef(null);
  const selectVisualOnKey = (event, card) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      setSelectedVisual(card);
    }
  };

  useEffect(() => {
    if (!selectedVisual) return undefined;
    const resetOutside = (event) => {
      if (!visualRef.current?.contains(event.target)) setSelectedVisual(null);
    };
    const resetEscape = (event) => {
      if (event.key === "Escape") setSelectedVisual(null);
    };
    document.addEventListener("pointerdown", resetOutside);
    document.addEventListener("keydown", resetEscape);
    return () => {
      document.removeEventListener("pointerdown", resetOutside);
      document.removeEventListener("keydown", resetEscape);
    };
  }, [selectedVisual]);

  return (
    <div className="welcome-page">
      <PublicHeader navigate={navigate} />
      <main className="welcome-main">
        <div className="welcome-copy">
          <div className="pill">
            <Sparkles size={15} /> A simpler way to borrow on campus
          </div>
          <LandingHeadline />
          <p>
            Find the right equipment, scan its code, and review your loan in a
            few clear steps. Built for every project you have in mind.
          </p>
          <div className="welcome-cta">
            <button
              className="button large"
              onClick={() => navigate("/signup")}
            >
              Create student account <ArrowRight size={18} />
            </button>
            <button
              className="button secondary large"
              onClick={() => navigate("/login")}
            >
              Log in
            </button>
          </div>
          <div className="welcome-trust">
            <ShieldCheck size={17} /> School email access only <span>•</span>{" "}
            Frontend demo
          </div>
        </div>
        <div
          ref={visualRef}
          className={`welcome-visual${selectedVisual ? " has-selection" : ""}`}
          onPointerLeave={(event) => {
            if (event.pointerType === "mouse") setSelectedVisual(null);
          }}
          onBlur={(event) => {
            if (!event.currentTarget.contains(event.relatedTarget)) setSelectedVisual(null);
          }}
        >
          <div className="visual-orb" />
          <div
            className={`visual-card visual-card-back${selectedVisual === "back" ? " is-selected" : ""}`}
            role="button"
            tabIndex={0}
            aria-label="Show available Canon EOS R50 card"
            aria-pressed={selectedVisual === "back"}
            onPointerLeave={(event) => {
              if (event.pointerType === "mouse") setSelectedVisual((current) => current === "back" ? null : current);
            }}
            onClick={() => setSelectedVisual("back")}
            onKeyDown={(event) => selectVisualOnKey(event, "back")}
          >
            <span className="visual-card-icon">
              <Camera size={30} />
            </span>
            <div>
              <strong>Canon EOS R50</strong>
              <small>2 units available</small>
            </div>
            <CheckCircle2 size={20} />
          </div>
          <div
            className={`visual-card visual-card-main${selectedVisual === "main" ? " is-selected" : ""}`}
            role="button"
            tabIndex={0}
            aria-label="Show equipment workspace card"
            aria-pressed={selectedVisual === "main"}
            onPointerLeave={(event) => {
              if (event.pointerType === "mouse") setSelectedVisual((current) => current === "main" ? null : current);
            }}
            onClick={() => setSelectedVisual("main")}
            onKeyDown={(event) => selectVisualOnKey(event, "main")}
          >
            <div className="visual-top">
              <span className="mini-brand">
                <Boxes size={18} /> equip.campus
              </span>
              <span className="visual-avatar">AR</span>
            </div>
            <p className="visual-hello">Good morning, Alex 👋</p>
            <h2>What will you create today?</h2>
            <div className="visual-search">
              <Search size={16} /> Search equipment
            </div>
            <div className="visual-preview">
              <ProductArt product={fixtureProducts[0]} size="large" />
              <div>
                <small>FEATURED EQUIPMENT</small>
                <strong>Canon EOS R50</strong>
                <span>Ready to borrow</span>
              </div>
            </div>
            <div className="visual-progress">
              <span>Find</span>
              <span>Scan</span>
              <span>Borrow</span>
            </div>
          </div>
          <div
            className={`visual-card visual-card-float${selectedVisual === "float" ? " is-selected" : ""}`}
            role="button"
            tabIndex={0}
            aria-label="Show scan a unit card"
            aria-pressed={selectedVisual === "float"}
            onPointerLeave={(event) => {
              if (event.pointerType === "mouse") setSelectedVisual((current) => current === "float" ? null : current);
            }}
            onClick={() => setSelectedVisual("float")}
            onKeyDown={(event) => selectVisualOnKey(event, "float")}
          >
            <span className="visual-card-icon">
              <QrCode size={27} />
            </span>
            <div>
              <strong>Scan a unit</strong>
              <small>Know exactly what you borrow</small>
            </div>
          </div>
        </div>
      </main>
      <section className="steps-section">
        <div className="section-intro">
          <span className="eyebrow">HOW IT WORKS</span>
          <h2>From idea to equipment in three steps</h2>
        </div>
        <div className="steps-grid">
          {[
            [
              Search,
              "Find",
              "Explore equipment and check live-ready availability.",
            ],
            [
              ScanLine,
              "Scan",
              "Capture the exact unit code or enter it manually.",
            ],
            [
              PackageCheck,
              "Borrow",
              "Choose a return time and review your request.",
            ],
          ].map(([Icon, title, text], index) => (
            <div className="step-card" key={title}>
              <span className="step-number">0{index + 1}</span>
              <span className="step-icon">
                <Icon size={27} />
              </span>
              <h3>{title}</h3>
              <p>{text}</p>
            </div>
          ))}
        </div>
      </section>
      <PublicFooter />
    </div>
  );
}

export function Auth({ mode, navigate, setSession, notify }) {
  const signup = mode === "signup";
  const [form, setForm] = useState({
    fullName: "",
    studentId: "",
    schoolEmail: "",
    yearLevel: "",
    program: "",
    address: "",
    password: "",
    confirm: "",
  });
  const [errors, setErrors] = useState({});
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [success, setSuccess] = useState(false);
  const [authError, setAuthError] = useState("");
  const [agreementAccepted, setAgreementAccepted] = useState(false);
  const [legalDocument, setLegalDocument] = useState(null);
  const signupReady =
    form.fullName.trim().length >= 2 &&
    /^[A-Za-z0-9-]{4,20}$/.test(form.studentId.trim()) &&
    schoolEmail(form.schoolEmail) &&
    Boolean(form.yearLevel) &&
    Boolean(form.program.trim()) &&
    form.address.trim().length >= 8 &&
    /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/.test(form.password) &&
    form.confirm === form.password &&
    agreementAccepted;
  const update = (key, value) => {
    setForm((old) => ({ ...old, [key]: value }));
    setErrors((old) => ({ ...old, [key]: "" }));
    setAuthError("");
  };
  const validate = () => {
    const next = {};
    if (signup && form.fullName.trim().length < 2)
      next.fullName = "Enter your full name.";
    if (signup && !/^[A-Za-z0-9-]{4,20}$/.test(form.studentId.trim()))
      next.studentId =
        "Enter a valid student ID (4–20 letters, numbers, or hyphens).";
    if (!schoolEmail(form.schoolEmail))
      next.schoolEmail = `Use your school email (${SCHOOL_DOMAINS.map((d) => `@${d}`).join(" or ")}).`;
    if (signup && !form.yearLevel) next.yearLevel = "Select your year level.";
    if (signup && !form.program.trim())
      next.program = "Enter your academic program.";
    if (signup && form.address.trim().length < 8)
      next.address = "Enter your complete address.";
    if (
      signup
        ? !/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/.test(form.password)
        : !form.password
    )
      next.password = signup
        ? "Use 8+ characters with upper and lowercase letters and a number."
        : "Enter your password.";
    if (signup && form.confirm !== form.password)
      next.confirm = "Passwords do not match.";
    if (signup && !agreementAccepted)
      next.agreement = "Please agree to the Terms of Use and Privacy Policy.";
    setErrors(next);
    return Object.keys(next).length === 0;
  };
  const submit = async (event) => {
    event.preventDefault();
    if (!validate() || busy) return;
    setBusy(true);
    const response = signup
      ? await demoService.signUp(form)
      : await demoService.logIn(form.schoolEmail, form.password);
    setBusy(false);
    if (!response.ok) {
      setAuthError(response.error.message);
      return;
    }
    if (signup) {
      setSuccess(true);
      return;
    }
    setSession(response.data);
    notify(
      `Welcome back, ${response.data.fullName.split(" ")[0]}. Demo session is active.`,
    );
    navigate(response.data.role === "ADMIN" ? "/admin/home" : "/student/home");
  };
  const demoLogin = async (role) => {
    setBusy(true);
    const email =
      role === "ADMIN"
        ? "morgan.reyes@university.edu"
        : "alex.rivera@university.edu";
    const response = await demoService.logIn(email, "Demo123!");
    setBusy(false);
    if (response.ok) {
      setSession(response.data);
      navigate(role === "ADMIN" ? "/admin/home" : "/student/home");
      notify(
        `${role === "ADMIN" ? "Administrator" : "Student"} demo session opened.`,
      );
    }
  };
  const passwordField = (
    <Field
      label="Password"
      error={errors.password}
      hint={
        signup
          ? "8+ characters, upper and lowercase letters, and a number"
          : ""
      }
      required
    >
      <div className="password-input">
        <input
          type={visible ? "text" : "password"}
          autoComplete={signup ? "new-password" : "current-password"}
          value={form.password}
          onChange={(e) => update("password", e.target.value)}
          placeholder="Enter password"
        />
        <IconButton
          icon={visible ? EyeOff : Eye}
          label={visible ? "Hide password" : "Show password"}
          onClick={() => setVisible(!visible)}
        />
      </div>
    </Field>
  );
  return (
    <div className={`auth-page${signup ? " auth-page-signup" : ""}`}>
      <div className="auth-aside">
        <button className="brand" onClick={() => navigate("/")}>
          <span className="brand-mark">
            <Boxes size={22} />
          </span>
          <span>
            equip<span className="brand-dot">.</span>campus
          </span>
        </button>
        <div className="auth-aside-content">
          <div className="pill">
            <Sparkles size={15} /> Made for campus life
          </div>
          <h2>
            Make room for
            <br />
            <em>your next big idea.</em>
          </h2>
          <p>
            Discover, borrow, and return the equipment your work needs, all in
            one place.
          </p>
          <div className="auth-art">
            <div className="auth-art-circle">
              <PackageCheck size={86} strokeWidth={1.2} />
            </div>
            <div className="auth-art-chip">
              <CheckCircle2 size={17} /> Equipment made accessible
            </div>
          </div>
        </div>
        <small>Student Equipment & Inventory Borrowing · Frontend demo</small>
      </div>
      <div className="auth-panel">
        <div className="auth-mobile-brand brand">
          <span className="brand-mark">
            <Boxes size={22} />
          </span>
          <span>
            equip<span className="brand-dot">.</span>campus
          </span>
        </div>
        <button className="back-link" onClick={() => navigate("/")}>
          <ArrowLeft size={17} /> Back to welcome
        </button>
        {success ? (
          <div className="auth-success">
            <span className="success-emblem">
              <Check size={32} />
            </span>
            <h1>You're all set</h1>
            <p>
              Your student account request passed local checks. This demo has no
              identity service, so no account was created.
            </p>
            <button className="button wide" onClick={() => navigate("/login")}>
              Go to log in <ArrowRight size={18} />
            </button>
          </div>
        ) : (
          <div className="auth-form-wrap">
            <h1>{signup ? "Create your account" : "Log in to your account"}</h1>
            <p className="auth-intro">
              {signup
                ? "Student accounts use your school email and academic details."
                : "Use your school email to access your equipment workspace."}
            </p>
            <form onSubmit={submit} noValidate>
              {signup && (
                <div className="form-grid">
                  <Field label="Full name" error={errors.fullName} required>
                    <input
                      value={form.fullName}
                      onChange={(e) => update("fullName", e.target.value)}
                      placeholder="Alex Rivera"
                    />
                  </Field>
                  <Field label="Student ID" error={errors.studentId} required>
                    <input
                      value={form.studentId}
                      onChange={(e) => update("studentId", e.target.value)}
                      placeholder="2023-01482"
                    />
                  </Field>
                </div>
              )}
              <Field
                label="School email"
                error={errors.schoolEmail}
                hint={`Allowed domain${SCHOOL_DOMAINS.length > 1 ? "s" : ""}: ${SCHOOL_DOMAINS.map((d) => `@${d}`).join(", ")}`}
                required
              >
                <input
                  type="email"
                  autoComplete="email"
                  value={form.schoolEmail}
                  onChange={(e) => update("schoolEmail", e.target.value)}
                  placeholder="you@university.edu"
                />
              </Field>
              {signup && (
                <>
                  <div className="form-grid">
                    <Field label="Year level" error={errors.yearLevel} required>
                      <select
                        value={form.yearLevel}
                        onChange={(e) => update("yearLevel", e.target.value)}
                      >
                        <option value="">Select year</option>
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
                    <Field
                      label="Academic program"
                      error={errors.program}
                      required
                    >
                      <input
                        value={form.program}
                        onChange={(e) => update("program", e.target.value)}
                        placeholder="BS Information Technology"
                      />
                    </Field>
                  </div>
                  <Field
                    label="Complete address"
                    error={errors.address}
                    required
                  >
                    <textarea
                      rows="2"
                      value={form.address}
                      onChange={(e) => update("address", e.target.value)}
                      placeholder="House number, street, city, province"
                    />
                  </Field>
                </>
              )}
              {signup ? (
                <div className="form-grid signup-password-grid">
                  {passwordField}
                  <Field label="Confirm password" error={errors.confirm} required>
                    <input
                      type={visible ? "text" : "password"}
                      autoComplete="new-password"
                      value={form.confirm}
                      onChange={(e) => update("confirm", e.target.value)}
                      placeholder="Repeat password"
                    />
                  </Field>
                </div>
              ) : passwordField}
              {!signup && (
                <button
                  type="button"
                  className="forgot-link"
                  onClick={() =>
                    notify(
                      "Password recovery requires a connected school identity service.",
                      "error",
                    )
                  }
                >
                  Forgot password?
                </button>
              )}
              {authError && (
                <div className="inline-error" role="alert">
                  <AlertCircle size={17} />
                  {authError}
                </div>
              )}
              {signup && (
                <div className="signup-agreement">
                  <input
                    id="signup-agreement"
                    type="checkbox"
                    checked={agreementAccepted}
                    aria-label="I have read and agree to the Terms of Use and Privacy Policy."
                    aria-invalid={Boolean(errors.agreement)}
                    onChange={(event) => {
                      setAgreementAccepted(event.target.checked);
                      setErrors((old) => ({ ...old, agreement: "" }));
                    }}
                  />
                  <div>
                    <label htmlFor="signup-agreement">I have read and agree to the </label>
                    <button type="button" className="signup-legal-link" onClick={() => setLegalDocument("terms")}>Terms of Use</button>
                    <span> and </span>
                    <button type="button" className="signup-legal-link" onClick={() => setLegalDocument("privacy")}>Privacy Policy</button>
                    <span>.</span>
                    {errors.agreement && <small className="field-error" role="alert">{errors.agreement}</small>}
                  </div>
                </div>
              )}
              <button className="button wide auth-submit" disabled={busy || (signup && !signupReady)}>
                {busy ? (
                  <>
                    <RefreshCw size={17} className="spin" /> Please wait…
                  </>
                ) : signup ? (
                  <>
                    Create student account <ArrowRight size={17} />
                  </>
                ) : (
                  <>
                    Log in <ArrowRight size={17} />
                  </>
                )}
              </button>
            </form>
            <p className="auth-switch">
              {signup ? "Already have an account?" : "New to equip.campus?"}{" "}
              <button onClick={() => navigate(signup ? "/login" : "/signup")}>
                {signup ? "Log in" : "Sign up"}
              </button>
            </p>
            {!signup && (
              <div className="demo-access">
                <div className="demo-access-title">
                  <Info size={16} /> Try the frontend demo
                </div>
                <p>No server account is required for these preview sessions.</p>
                <div>
                  <button
                    className="button secondary"
                    disabled={busy}
                    onClick={() => demoLogin("STUDENT")}
                  >
                    Student demo
                  </button>
                  <button
                    className="button secondary"
                    disabled={busy}
                    onClick={() => demoLogin("ADMIN")}
                  >
                    Admin demo
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
        {signup && legalDocument && (
          <Modal
            title={legalDocument === "terms" ? "Terms of Use" : "Privacy Policy"}
            size="wide"
            onClose={() => setLegalDocument(null)}
          >
            <div className="signup-legal-document">
              <div className="signup-legal-draft">
                <Info size={18} />
                <span>Draft placeholder content. Institutional and legal review is required before deployment.</span>
              </div>
              {legalDocument === "terms" ? (
                <>
                  <p>These draft terms describe how the campus equipment borrowing service is intended to work. They are provided for this frontend demonstration and are not a final institutional agreement.</p>
                  <h3>Eligibility and account use</h3>
                  <p>Students should use their own school account and provide accurate academic and contact details. Access and borrowing eligibility will be verified by the institution when backend services are connected.</p>
                  <h3>Borrowing and returns</h3>
                  <p>Borrowers should check equipment condition when collecting a unit, use it responsibly, and return it by the agreed due date. Administrators may record checkouts, returns, maintenance needs, and overdue items.</p>
                  <h3>Availability and changes</h3>
                  <p>Catalog availability and due dates shown in this demo are sample data. Final borrowing rules, fees, and dispute procedures must be supplied and approved by the institution before launch.</p>
                </>
              ) : (
                <>
                  <p>This draft notice explains the information this service may need for student registration and equipment loans. It is placeholder content for review before deployment.</p>
                  <h3>Information used</h3>
                  <p>The registration form asks for your name, student ID, school email, year level, academic program, address, and password. A production service may also record borrowing and return activity.</p>
                  <h3>How information is used</h3>
                  <p>The intended uses are account verification, equipment inventory tracking, loan administration, and return reminders. The institution must confirm its lawful basis, retention period, access controls, and contact details in the final policy.</p>
                  <h3>Current demo behavior</h3>
                  <p>This frontend demo performs local form checks and does not create a real account or submit registration details to a server. Do not enter a password you use elsewhere.</p>
                </>
              )}
            </div>
          </Modal>
        )}
      </div>
    </div>
  );
}
