import { useEffect, useRef, useState } from "react";
import {
  Bell,
  LogOut,
  ChevronRight,
  X,
  Menu,
  Boxes,
} from "lucide-react";
import { SCHOOL_NAME } from "../data/fixtures";
import { Badge, IconButton } from "../components/ui";
import { studentLinks, adminLinks } from "../utils/domain";
import { HelpCarousel } from "./HelpCarousel";

export function Shell({
  role,
  session,
  avatar,
  route,
  navigate,
  logout,
  children,
  notify,
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const notificationRef = useRef(null);
  const notificationButtonRef = useRef(null);
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
  useEffect(() => {
    if (!notificationsOpen) return undefined;
    const closeOutside = (event) => {
      if (!notificationRef.current?.contains(event.target)) setNotificationsOpen(false);
    };
    const closeOnEscape = (event) => {
      if (event.key === "Escape") {
        setNotificationsOpen(false);
        notificationButtonRef.current?.focus();
      }
    };
    document.addEventListener("pointerdown", closeOutside);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOutside);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [notificationsOpen]);
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
              aria-current={current === name.toLowerCase() ? "page" : undefined}
              onClick={() => {
                navigate(prefix + "/" + name.toLowerCase());
                setMenuOpen(false);
              }}
            >
              <Icon size={19} />
              <span>{name}</span>
              <span className="nav-active-dot" aria-hidden="true" />
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <HelpCarousel
            key={role}
            role={role}
            navigate={(page) => {
              navigate(prefix + "/" + page);
              setMenuOpen(false);
            }}
          />
          <button
            className="sidebar-profile"
            onClick={() => navigate(prefix + "/settings")}
          >
            <span className="avatar">
              {avatar ? <img src={avatar} alt="" /> : session.fullName
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
      <button
        className={`mobile-scrim ${menuOpen ? "visible" : ""}`}
        aria-label="Close menu"
        aria-hidden={!menuOpen}
        tabIndex={menuOpen ? 0 : -1}
        onClick={() => setMenuOpen(false)}
      />
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
            <div className="notification-wrap" ref={notificationRef}>
              <IconButton
                icon={Bell}
                label="Notifications"
                onClick={() => setNotificationsOpen(!notificationsOpen)}
                buttonRef={notificationButtonRef}
                aria-expanded={notificationsOpen}
                aria-controls="notifications-panel"
              />
              <span className="notification-dot" />
              {notificationsOpen && (
                <div className="notification-popover" id="notifications-panel">
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
                {avatar ? <img src={avatar} alt="" /> : session.fullName
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
