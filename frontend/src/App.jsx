import { useState, useEffect } from "react";
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
  const navigate = (path) => {
    window.history.pushState({}, "", path);
    setRoute(path);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const notify = (text, tone = "success") => {
    setToast({ text, tone });
    window.setTimeout(() => setToast(null), 5500);
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
    const onPop = () => setRoute(window.location.pathname);
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, []);
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
      {content}
      <Notice message={toast} onClose={() => setToast(null)} />
    </>
  );
}

export default App;
