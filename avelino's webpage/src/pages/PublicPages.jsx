import { useEffect, useRef, useState } from "react";
import {
  ScanLine,
  Search,
  Camera,
  ArrowRight,
  ArrowLeft,
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
} from "lucide-react";
import {
  SCHOOL_NAME,
  products as fixtureProducts,
} from "../data/fixtures";
import { apiService } from "../services/apiService";
import { IconButton, Field, Modal, ProductArt } from "../components/ui";
import { schoolEmail } from "../utils/domain";
import { privacySections, termsSections } from "../data/policies";

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
            <ShieldCheck size={17} /> Verified account access <span>•</span>{" "}
            ENcoRE inventory access
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
    phone: "",
    yearLevel: "",
    program: "",
    section: "",
    address: "",
    password: "",
    confirm: "",
  });
  const [errors, setErrors] = useState({});
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [challenge, setChallenge] = useState(null);
  const [code, setCode] = useState(Array(6).fill(""));
  const codeInputs = useRef([]);
  const [codeBusy, setCodeBusy] = useState(false);
  const [authError, setAuthError] = useState("");
  const [agreementAccepted, setAgreementAccepted] = useState(false);
  const [legalDocument, setLegalDocument] = useState(null);
  const signupReady =
    form.fullName.trim().length >= 2 &&
    /^[A-Za-z0-9-]{4,20}$/.test(form.studentId.trim()) &&
    schoolEmail(form.schoolEmail) &&
    /^\+?[0-9() -]{7,30}$/.test(form.phone.trim()) &&
    Boolean(form.yearLevel) &&
    Boolean(form.program.trim()) &&
    Boolean(form.section.trim()) &&
    form.address.trim().length >= 8 &&
    form.password.length >= 12 && form.password.length <= 72 &&
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
    if (!schoolEmail(form.schoolEmail)) next.schoolEmail = "Enter a valid email address.";
    if (signup && !/^\+?[0-9() -]{7,30}$/.test(form.phone.trim()))
      next.phone = "Enter a valid phone number.";
    if (signup && !form.yearLevel) next.yearLevel = "Select your year level.";
    if (signup && !form.program.trim())
      next.program = "Enter your academic program.";
    if (signup && !form.section.trim()) next.section = "Enter your section or block.";
    if (signup && form.address.trim().length < 8)
      next.address = "Enter your complete address.";
    if (
      signup ? form.password.length < 12 || form.password.length > 72 : !form.password
    )
      next.password = signup
        ? "Use a password of 12 to 72 characters."
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
    try {
      const response = signup
        ? await apiService.signUp(form)
        : await apiService.logIn(form.schoolEmail, form.password);
      if (!response.ok) {
        setAuthError(response.error?.message || "Could not complete this request.");
        return;
      }
      if (response.data.verificationRequired) {
        setChallenge(response.data);
        return;
      }
      setSession(response.data);
      notify(`Welcome back, ${response.data.fullName.split(" ")[0]}.`);
      navigate(response.data.role === "ADMIN" ? "/admin/home" : "/student/home");
    } catch {
      setAuthError("Could not reach the account service. Please try again.");
    } finally {
      setBusy(false);
    }
  };
  const verifyCode = async (digits) => {
    if (!challenge || codeBusy || digits.length !== 6) return;
    setCodeBusy(true);
    setAuthError("");
    try {
      const response = await apiService.verify(challenge.challengeId, digits);
      if (!response.ok) {
        setAuthError(response.error?.message || "Incorrect verification code.");
        setCode(Array(6).fill(""));
        codeInputs.current[0]?.focus();
        return;
      }
      setSession(response.data);
      navigate(response.data.role === "ADMIN" ? "/admin/home" : "/student/home");
    } finally { setCodeBusy(false); }
  };
  const updateCode = (index, value) => {
    const digits = value.replace(/\D/g, "").slice(0, 6);
    if (!digits) return;
    const next = [...code];
    for (let offset = 0; offset < digits.length && index + offset < 6; offset++) next[index + offset] = digits[offset];
    setCode(next);
    const nextIndex = Math.min(index + digits.length, 5);
    codeInputs.current[nextIndex]?.focus();
    if (next.every(Boolean)) verifyCode(next.join(""));
  };
  const passwordField = (
    <Field
      label="Password"
      error={errors.password}
      hint={
        signup
          ? "12 to 72 characters"
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
        <small>ENcoRE · Student Equipment &amp; Inventory Borrowing</small>
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
        {challenge ? (
          <div className="auth-success">
            <span className="success-emblem">
              <ShieldCheck size={32} />
            </span>
            <h1>Check your email</h1>
            <p>Enter the six-digit code sent to {challenge.email}. The code expires in 10 minutes.</p>
            <div className="verification-boxes" aria-label="Email verification code">
              {code.map((digit, index) => (
                <input
                  key={index}
                  ref={(element) => { codeInputs.current[index] = element; }}
                  aria-label={`Digit ${index + 1}`}
                  inputMode="numeric"
                  autoComplete={index === 0 ? "one-time-code" : "off"}
                  maxLength={6}
                  value={digit}
                  disabled={codeBusy}
                  onChange={(event) => updateCode(index, event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Backspace") {
                      const next = [...code];
                      next[index] = "";
                      setCode(next);
                      if (!code[index]) codeInputs.current[Math.max(index - 1, 0)]?.focus();
                    }
                  }}
                />
              ))}
            </div>
            {authError && <div className="inline-error" role="alert">{authError}</div>}
            <button className="button secondary wide" onClick={() => { setChallenge(null); setCode(Array(6).fill("")); }}>
              Back to sign in <ArrowRight size={18} />
            </button>
          </div>
        ) : (
          <div className="auth-form-wrap">
            <h1>{signup ? "Create your account" : "Log in to your account"}</h1>
            <p className="auth-intro">
              {signup
                ? "Create your ENcoRE student account with your academic details."
                : "Use your ENcoRE email to access your equipment workspace."}
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
                hint="Use the email connected to your ENcoRE account."
                required
              >
                <input
                  type="email"
                  autoComplete="email"
                  value={form.schoolEmail}
                  onChange={(e) => update("schoolEmail", e.target.value)}
                  placeholder="you@fit.edu.ph"
                />
              </Field>
              {signup && (
                <>
                  <div className="form-grid">
                    <Field label="Phone number" error={errors.phone} required>
                      <input type="tel" autoComplete="tel" value={form.phone}
                        onChange={(e) => update("phone", e.target.value)} placeholder="09123456789" />
                    </Field>
                    <Field label="Section / block" error={errors.section} required>
                      <input value={form.section} onChange={(e) => update("section", e.target.value)} placeholder="QA 1" />
                    </Field>
                  </div>
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
                  onClick={async () => {
                    if (!schoolEmail(form.schoolEmail)) {
                      setAuthError("Enter your account email, then request a reset link.");
                      return;
                    }
                    const response = await apiService.requestPasswordReset(form.schoolEmail);
                    if (!response.ok) setAuthError(response.error?.message || "Could not request a reset link.");
                    else notify("Check your email for password reset steps.");
                  }}
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
              {signup ? "Already have an account?" : "New to ENcoRE?"}{" "}
              <button onClick={() => navigate(signup ? "/login" : "/signup")}>
                {signup ? "Log in" : "Sign up"}
              </button>
            </p>
          </div>
        )}
        {signup && legalDocument && (
          <Modal
            title={legalDocument === "terms" ? "Terms of Use" : "Privacy Policy"}
            size="wide"
            onClose={() => setLegalDocument(null)}
          >
            <div className="signup-legal-document">
              {(legalDocument === "terms" ? termsSections : privacySections).map(([title, detail]) => (
                <section key={title}><h3>{title}</h3><p>{detail}</p></section>
              ))}
            </div>
          </Modal>
        )}
      </div>
    </div>
  );
}
