import { useState, useEffect, useCallback, useRef } from "react";
import { Search, ArrowRight } from "lucide-react";
import {
  loans as fixtureLoans,
  products as fixtureProducts,
  transactions as fixtureTransactions,
  units as fixtureUnits,
} from "./data/fixtures";
import { demoService } from "./services/demoService";
import { Notice } from "./components/ui";

import { Welcome, Auth } from "./pages/PublicPages";
import { AboutPage, ContactPage, GoalPage } from "./pages/PublicInfoPages";
import { Shell } from "./components/Shell";
import {
  StudentHome,
  StudentScan,
  StudentHistory,
  SettingsPage,
} from "./pages/StudentPages";
import {
  AdminHome,
  AdminProducts,
  AdminScan,
  AdminHistory,
  AdminUsers,
} from "./pages/AdminPages";
import "./App.css";

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

function App() {
  const [route, setRoute] = useState(window.location.pathname);
  const [routePhase, setRoutePhase] = useState("idle");
  const routeRef = useRef(window.location.pathname);
  const pendingRoute = useRef(null);
  const exitTimer = useRef(null);
  const enterTimer = useRef(null);
  const toastTimer = useRef(null);
  const toastExitTimer = useRef(null);
  const [session, setSessionState] = useState(() => {
    try {
      return JSON.parse(sessionStorage.getItem("equip-demo-session"));
    } catch {
      return null;
    }
  });
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
    if (path === window.location.pathname) return;
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
    sessionStorage.setItem("equip-demo-session", JSON.stringify(user));
  };
  const logout = async () => {
    await demoService.logOut();
    setSessionState(null);
    sessionStorage.removeItem("equip-demo-session");
    navigate("/");
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
    const onPop = () => transitionTo(window.location.pathname);
    window.addEventListener("popstate", onPop);
    return () => {
      window.removeEventListener("popstate", onPop);
      window.clearTimeout(exitTimer.current);
      window.clearTimeout(enterTimer.current);
      window.clearTimeout(toastTimer.current);
      window.clearTimeout(toastExitTimer.current);
    };
  }, [transitionTo]);
  const page = route.split("/")[2];
  let content;
  if (route === "/") content = <Welcome navigate={navigate} />;
  else if (route === "/about") content = <AboutPage navigate={navigate} />;
  else if (route === "/contact") content = <ContactPage navigate={navigate} />;
  else if (route === "/goal") content = <GoalPage navigate={navigate} />;
  else if (route === "/login" || route === "/signup")
    content = (
      <Auth
        key={route}
        mode={route.slice(1)}
        navigate={navigate}
        setSession={setSession}
        notify={notify}
      />
    );
  else if (route.startsWith("/student/")) {
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
        child = <StudentHistory session={session} {...data} />;
      else if (page === "settings")
        child = (
          <SettingsPage
            session={session}
            role="STUDENT"
            logout={logout}
            notify={notify}
          />
        );
      else child = <NotFound navigate={navigate} session={session} />;
      content = (
        <Shell
          role="STUDENT"
          session={session}
          route={route}
          navigate={navigate}
          logout={logout}
          notify={notify}
        >
          {child}
        </Shell>
      );
    }
  } else if (route.startsWith("/admin/")) {
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
          />
        );
      else if (page === "products")
        child = (
          <AdminProducts
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
      else if (page === "history") child = <AdminHistory {...data} />;
      else if (page === "users")
        child = <AdminUsers {...data} notify={notify} />;
      else if (page === "settings")
        child = (
          <SettingsPage
            session={session}
            role="ADMIN"
            logout={logout}
            notify={notify}
          />
        );
      else child = <NotFound navigate={navigate} session={session} />;
      content = (
        <Shell
          role="ADMIN"
          session={session}
          route={route}
          navigate={navigate}
          logout={logout}
          notify={notify}
        >
          {child}
        </Shell>
      );
    }
  } else content = <NotFound navigate={navigate} session={session} />;
  return (
    <>
      <div className="route-frame" data-phase={routePhase}>
        {content}
      </div>
      <Notice message={toast} onClose={dismissNotice} />
    </>
  );
}

export default App;
