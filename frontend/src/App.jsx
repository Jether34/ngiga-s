import { Component, Suspense, lazy, useState, useEffect, useCallback, useRef } from "react";
import { Search, ArrowRight } from "lucide-react";
import {
  loans as fixtureLoans,
  products as fixtureProducts,
  transactions as fixtureTransactions,
  units as fixtureUnits,
} from "./data/fixtures";
import { demoService } from "./services/demoService";
import { readAvatar, readTheme, saveAvatar, saveTheme } from "./utils/preferences";
import { Loading, Notice } from "./components/ui";

import { Welcome, Auth } from "./pages/PublicPages";
import { AboutPage, ContactPage, GoalPage } from "./pages/PublicInfoPages";
import { Shell } from "./components/Shell";
const loadStudentPages = () => import("./pages/StudentPages");
const loadAdminPages = () => import("./pages/AdminPages");
const lazyNamed = (load, name) => lazy(() => load().then((module) => ({ default: module[name] })));
const StudentHome = lazyNamed(loadStudentPages, "StudentHome");
const StudentScan = lazyNamed(loadStudentPages, "StudentScan");
const StudentHistory = lazyNamed(loadStudentPages, "StudentHistory");
const SettingsPage = lazyNamed(loadStudentPages, "SettingsPage");
const AdminHome = lazyNamed(loadAdminPages, "AdminHome");
const AdminProducts = lazyNamed(loadAdminPages, "AdminProducts");
const AdminScan = lazyNamed(loadAdminPages, "AdminScan");
const AdminHistory = lazyNamed(loadAdminPages, "AdminHistory");
const AdminUsers = lazyNamed(loadAdminPages, "AdminUsers");
import "./App.css";

const currentLocation = () => window.location.pathname + window.location.search;

function readDemoSession() {
  try {
    const user = JSON.parse(sessionStorage.getItem("equip-demo-session"));
    return user && ["STUDENT", "ADMIN"].includes(user.role) &&
      typeof user.id === "string" && typeof user.fullName === "string" &&
      typeof user.schoolEmail === "string" ? user : null;
  } catch {
    return null;
  }
}

function NotFound({ navigate, session }) {
  return (
    <div className="not-found">
      <span className="empty-icon">
        <Search size={31} />
      </span>
      <span className="eyebrow">404 / PAGE NOT FOUND</span>
      <h1>We couldn't find that page.</h1>
      <p>Check the address or return to your workspace.</p>
      <button
        className="button"
        onClick={() =>
          navigate(
            session
              ? session.role === "ADMIN"
                ? "/admin/home"
                : "/student/home"
              : "/",
          )
        }
      >
        Go to home <ArrowRight size={17} />
      </button>
    </div>
  );
}

class PageErrorBoundary extends Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error, details) {
    console.error("Page rendering failed", error, details);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <main className="not-found" role="alert">
        <span className="eyebrow">PAGE ERROR</span>
        <h1>Something went wrong.</h1>
        <p>Reload the page to return to the equipment workspace.</p>
        <button className="button" onClick={() => window.location.reload()}>Reload page</button>
      </main>
    );
  }
}

function App() {
  const [theme, setTheme] = useState(readTheme);
  const [route, setRoute] = useState(currentLocation);
  const [routePhase, setRoutePhase] = useState("idle");
  const routeRef = useRef(currentLocation());
  const pendingRoute = useRef(null);
  const exitTimer = useRef(null);
  const enterTimer = useRef(null);
  const toastTimer = useRef(null);
  const toastExitTimer = useRef(null);
  const [session, setSessionState] = useState(readDemoSession);
  const [helpTipIndexes, setHelpTipIndexes] = useState({ ADMIN: 0, STUDENT: 0 });
  const setHelpTipIndex = useCallback((role, index) => {
    setHelpTipIndexes((current) => ({ ...current, [role]: index }));
  }, []);
  const [avatar, setAvatar] = useState(() => readAvatar(readDemoSession()?.schoolEmail));
  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const apply = () => {
      document.documentElement.dataset.theme = theme === "system" ? (media.matches ? "dark" : "light") : theme;
    };
    apply();
    media.addEventListener("change", apply);
    return () => media.removeEventListener("change", apply);
  }, [theme]);
  const updateTheme = (value) => {
    setTheme(value);
    saveTheme(value);
  };
  const updateAvatar = (dataUrl) => {
    saveAvatar(session.schoolEmail, dataUrl);
    setAvatar(dataUrl);
  };
  const [data, setData] = useState({
    products: fixtureProducts,
    units: fixtureUnits,
    loans: fixtureLoans,
    transactions: fixtureTransactions,
  });
  const [loading, setLoading] = useState(false);
  const [dataError, setDataError] = useState("");
  const [toast, setToast] = useState(null);
  const transitionTo = useCallback((path) => {
    if (path === (pendingRoute.current || routeRef.current)) return;
    window.clearTimeout(exitTimer.current);
    window.clearTimeout(enterTimer.current);
    pendingRoute.current = path;
    if (path === routeRef.current) {
      pendingRoute.current = null;
      setRoutePhase("idle");
      return;
    }
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      routeRef.current = path;
      pendingRoute.current = null;
      setRoute(path);
      setRoutePhase("idle");
      window.scrollTo(0, 0);
      return;
    }
    setRoutePhase("exit");
    exitTimer.current = window.setTimeout(() => {
      const next = pendingRoute.current;
      pendingRoute.current = null;
      routeRef.current = next;
      setRoute(next);
      setRoutePhase("enter");
      window.scrollTo(0, 0);
      enterTimer.current = window.setTimeout(() => setRoutePhase("idle"), 330);
    }, 170);
  }, []);
  const navigate = (path) => {
    if (path === currentLocation()) return;
    window.history.pushState({}, "", path);
    transitionTo(path);
  };
  const dismissNotice = () => {
    window.clearTimeout(toastTimer.current);
    window.clearTimeout(toastExitTimer.current);
    setToast((current) => current ? { ...current, leaving: true } : null);
    toastExitTimer.current = window.setTimeout(() => setToast(null), 220);
  };
  const notify = (text, tone = "success") => {
    window.clearTimeout(toastTimer.current);
    window.clearTimeout(toastExitTimer.current);
    setToast({ text, tone, leaving: false });
    toastTimer.current = window.setTimeout(() => {
      setToast((current) => current ? { ...current, leaving: true } : null);
      toastExitTimer.current = window.setTimeout(() => setToast(null), 220);
    }, 5300);
  };
  const setSession = (user) => {
    setSessionState(user);
    setAvatar(readAvatar(user?.schoolEmail));
    try {
      sessionStorage.setItem("equip-demo-session", JSON.stringify(user));
    } catch {
      notify("Demo session is active, but browser storage is unavailable.", "error");
    }
  };
  const logout = async () => {
    try {
      await demoService.logOut();
    } catch {
      // A failed network sign-out must not leave a demo session open locally.
    } finally {
      setSessionState(null);
      setAvatar("");
      try { sessionStorage.removeItem("equip-demo-session"); } catch { /* storage may be disabled */ }
      navigate("/");
    }
  };
  const refresh = async () => {
    setLoading(true);
    setDataError("");
    try {
      const [p, u, l, t] = await Promise.all([
        demoService.listProducts(),
        demoService.listUnits(),
        demoService.listLoans(),
        demoService.listTransactions(),
      ]);
      const failed = [p, u, l, t].find((item) => !item.ok);
      if (failed) throw new Error(failed.error.message);
      setData({
        products: p.data,
        units: u.data,
        loans: l.data,
        transactions: t.data,
      });
      notify("Demo fixture data refreshed.");
    } catch (error) {
      setDataError(error.message || "Could not load catalog data.");
      notify("Could not refresh data. Try again.", "error");
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => {
    const onPop = () => transitionTo(currentLocation());
    window.addEventListener("popstate", onPop);
    return () => {
      window.removeEventListener("popstate", onPop);
      window.clearTimeout(exitTimer.current);
      window.clearTimeout(enterTimer.current);
      window.clearTimeout(toastTimer.current);
      window.clearTimeout(toastExitTimer.current);
    };
  }, [transitionTo]);
  const pathname = route.split("?")[0];
  const page = pathname.split("/")[2];
  let content;
  if (pathname === "/") content = <Welcome navigate={navigate} />;
  else if (pathname === "/about") content = <AboutPage navigate={navigate} />;
  else if (pathname === "/contact") content = <ContactPage navigate={navigate} />;
  else if (pathname === "/goal") content = <GoalPage navigate={navigate} />;
  else if (pathname === "/login" || pathname === "/signup")
    content = (
      <Auth
        key={route}
        mode={pathname.slice(1)}
        navigate={navigate}
        setSession={setSession}
        notify={notify}
      />
    );
  else if (pathname.startsWith("/student/")) {
    if (!session || session.role !== "STUDENT")
      content = <NotFound navigate={navigate} session={session} />;
    else {
      let child;
      if (page === "home")
        child = (
          <StudentHome
            session={session}
            {...data}
            navigate={navigate}
            refresh={refresh}
            loading={loading}
            dataError={dataError}
          />
        );
      else if (page === "scan")
        child = <StudentScan session={session} {...data} notify={notify} />;
      else if (page === "history")
        child = <StudentHistory key={route} session={session} {...data} />;
      else if (page === "settings")
        child = (
          <SettingsPage
            session={session}
            role="STUDENT"
            logout={logout}
            notify={notify}
            avatar={avatar}
            updateAvatar={updateAvatar}
            theme={theme}
            updateTheme={updateTheme}
          />
        );
      else child = <NotFound navigate={navigate} session={session} />;
      content = (
        <Shell
          role="STUDENT"
          session={session}
          avatar={avatar}
          route={route}
          navigate={navigate}
          logout={logout}
          notify={notify}
          products={data.products}
          loans={data.loans}
          helpTipIndex={helpTipIndexes.STUDENT}
          setHelpTipIndex={setHelpTipIndex}
        >
          {child}
        </Shell>
      );
    }
  } else if (pathname.startsWith("/admin/")) {
    if (!session || session.role !== "ADMIN")
      content = <NotFound navigate={navigate} session={session} />;
    else {
      let child;
      if (page === "home")
        child = (
          <AdminHome
            {...data}
            navigate={navigate}
            refresh={refresh}
            loading={loading}
            dataError={dataError}
          />
        );
      else if (page === "products")
        child = (
          <AdminProducts
            key={route}
            products={data.products}
            setProducts={(products) =>
              setData((old) => ({
                ...old,
                products:
                  typeof products === "function"
                    ? products(old.products)
                    : products,
              }))
            }
            units={data.units}
            navigate={navigate}
            notify={notify}
          />
        );
      else if (page === "scan") child = <AdminScan {...data} notify={notify} />;
      else if (page === "history") child = <AdminHistory key={route} {...data} />;
      else if (page === "users")
        child = <AdminUsers {...data} notify={notify} />;
      else if (page === "settings")
        child = (
          <SettingsPage
            session={session}
            role="ADMIN"
            logout={logout}
            notify={notify}
            avatar={avatar}
            updateAvatar={updateAvatar}
            theme={theme}
            updateTheme={updateTheme}
          />
        );
      else child = <NotFound navigate={navigate} session={session} />;
      content = (
        <Shell
          role="ADMIN"
          session={session}
          avatar={avatar}
          route={route}
          navigate={navigate}
          logout={logout}
          notify={notify}
          products={data.products}
          loans={data.loans}
          helpTipIndex={helpTipIndexes.ADMIN}
          setHelpTipIndex={setHelpTipIndex}
        >
          {child}
        </Shell>
      );
    }
  } else content = <NotFound navigate={navigate} session={session} />;
  return (
    <>
      <div className="route-frame" data-phase={routePhase}>
        <PageErrorBoundary key={route}>
          <Suspense fallback={<div className="route-loading"><Loading /></div>}>{content}</Suspense>
        </PageErrorBoundary>
      </div>
      <Notice message={toast} onClose={dismissNotice} />
    </>
  );
}

export default App;
