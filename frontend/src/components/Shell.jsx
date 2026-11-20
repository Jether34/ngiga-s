import { useState } from "react";
import {
  Bell,
  LogOut,
  ArrowRight,
  ChevronRight,
  X,
  Menu,
  Sparkles,
  Boxes,
} from "lucide-react";
import { SCHOOL_NAME } from "../data/fixtures";
import { Badge, IconButton } from "../components/ui";
import { studentLinks, adminLinks } from "../utils/domain";

export function Shell({
  role,
  session,
  route,
  navigate,
  logout,
  children,
  notify,
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const links = role === "ADMIN" ? adminLinks : studentLinks;
  const prefix = role === "ADMIN" ? "/admin" : "/student";
  const current = route.split("/")[2] || "home";
  const notices =
    role === "ADMIN"
      ? [
          "3 product types are at or below minimum stock.",
          "Two active loans are overdue.",
        ]
      : [
          "A borrowed item is overdue. Review your history.",
          "Your receipt is pending generation.",
        ];
  return (
    <div className="app-shell">
      <aside className={`sidebar ${menuOpen ? "open" : ""}`}>
        <div className="sidebar-top">
          <button className="brand" onClick={() => navigate(prefix + "/home")}>
            <span className="brand-mark">
              <Boxes size={21} />
            </span>
            <span>
              equip<span className="brand-dot">.</span>campus
            </span>
          </button>
          <IconButton
            icon={X}
            label="Close menu"
            className="mobile-close"
            onClick={() => setMenuOpen(false)}
          />
        </div>
        <div className="workspace-label">
          {role === "ADMIN" ? "ADMIN WORKSPACE" : "STUDENT WORKSPACE"}
        </div>
        <nav aria-label={`${role.toLowerCase()} navigation`}>
          {links.map(([name, Icon]) => (
            <button
              key={name}
              className={`nav-link ${current === name.toLowerCase() ? "active" : ""}`}
              onClick={() => {
                navigate(prefix + "/" + name.toLowerCase());
                setMenuOpen(false);
              }}
            >
              <Icon size={19} />
              <span>{name}</span>
              {current === name.toLowerCase() && (
                <span className="nav-active-dot" />
              )}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sidebar-help">
            <span>
              <Sparkles size={18} />
            </span>
            <strong>Need a hand?</strong>
            <p>Scan a unit code or explore the equipment catalog.</p>
            <button
              onClick={() => {
                navigate(prefix + "/scan");
                setMenuOpen(false);
              }}
            >
              Start scanning <ArrowRight size={15} />
            </button>
          </div>
          <button
            className="sidebar-profile"
            onClick={() => navigate(prefix + "/settings")}
          >
            <span className="avatar">
              {session.fullName
                .split(" ")
                .map((x) => x[0])
                .slice(0, 2)
                .join("")}
            </span>
            <span>
              <strong>{session.fullName}</strong>
              <small>
                {role === "ADMIN" ? "Administrator" : session.studentId}
              </small>
            </span>
            <ChevronRight size={16} />
          </button>
        </div>
      </aside>
      {menuOpen && (
        <button
          className="mobile-scrim"
          aria-label="Close menu"
          onClick={() => setMenuOpen(false)}
        />
      )}
      <div className="app-main">
        <header className="topbar">
          <div className="topbar-left">
            <IconButton
              icon={Menu}
              label="Open menu"
              className="menu-toggle"
              onClick={() => setMenuOpen(true)}
            />
            <div className="breadcrumb">
              Workspace <ChevronRight size={15} />{" "}
              <strong>{current[0].toUpperCase() + current.slice(1)}</strong>
            </div>
          </div>
          <div className="topbar-right">
            <Badge tone="warning">Demo data</Badge>
            <div className="notification-wrap">
              <IconButton
                icon={Bell}
                label="Notifications"
                onClick={() => setNotificationsOpen(!notificationsOpen)}
              />
              <span className="notification-dot" />
              {notificationsOpen && (
                <div className="notification-popover">
                  <div className="popover-head">
                    <strong>Notifications</strong>
                    <IconButton
                      icon={X}
                      label="Close notifications"
                      onClick={() => setNotificationsOpen(false)}
                    />
                  </div>
                  {notices.map((text) => (
                    <div className="notification-item" key={text}>
                      <span className="notice-dot" />
                      {text}
                    </div>
                  ))}
                  <small>Demo alerts based on fixture data</small>
                </div>
              )}
            </div>
            <button
              className="topbar-user"
              onClick={() => navigate(prefix + "/settings")}
            >
              <span className="avatar small-avatar">
                {session.fullName
                  .split(" ")
                  .map((x) => x[0])
                  .slice(0, 2)
                  .join("")}
              </span>
              <span>{session.fullName.split(" ")[0]}</span>
            </button>
          </div>
        </header>
        <main className="content">{children}</main>
        <footer className="app-footer">
          <span>
            © {new Date().getFullYear()} {SCHOOL_NAME}
          </span>
          <span>Frontend demo · No backend connection</span>
        </footer>
      </div>
      <button
        className="floating-logout"
        title="Log out"
        aria-label="Log out"
        onClick={() => {
          logout();
          notify("Demo session ended.");
        }}
      >
        <LogOut size={19} />
      </button>
    </div>
  );
}
