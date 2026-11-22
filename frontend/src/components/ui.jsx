import { useCallback, useEffect, useRef, useState } from "react";
import {
  Package,
  Search,
  Camera,
  Mic,
  Laptop,
  Video,
  ChevronRight,
  X,
  AlertCircle,
  PackageOpen,
  RefreshCw,
  CheckCircle2,
  Info,
} from "lucide-react";
import { number } from "../utils/domain";

const icons = { camera: Camera, audio: Mic, laptop: Laptop, video: Video };

export function Badge({ children, tone = "neutral" }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}
export function IconButton({ icon: Icon, label, onClick, className = "", buttonRef, ...props }) {
  return (
    <button
      ref={buttonRef}
      type="button"
      className={`icon-button ${className}`}
      aria-label={label}
      title={label}
      onClick={onClick}
      {...props}
    >
      <Icon size={18} />
    </button>
  );
}
export function Empty({
  icon: Icon = PackageOpen,
  title = "Nothing here yet",
  text,
}) {
  return (
    <div className="empty">
      <span className="empty-icon">
        <Icon size={27} />
      </span>
      <h3>{title}</h3>
      {text && <p>{text}</p>}
    </div>
  );
}
export function Notice({ message, onClose }) {
  return (
    message && (
      <div key={`${message.tone}:${message.text}`} className={`toast ${message.tone || "success"}${message.leaving ? " is-leaving" : ""}`} role={message.tone === "error" ? "alert" : "status"}>
        <span>
          {message.tone === "error" ? (
            <AlertCircle size={18} />
          ) : (
            <CheckCircle2 size={18} />
          )}
        </span>
        <span>{message.text}</span>
        <IconButton icon={X} label="Dismiss notification" onClick={onClose} />
      </div>
    )
  );
}
export function Field({ label, error, hint, children, required }) {
  return (
    <div className="field">
      <label>
        {label}
        {required && <span className="required"> *</span>}
        {children}
      </label>
      {hint && <small>{hint}</small>}
      {error && (
        <small className="field-error" role="alert">
          {error}
        </small>
      )}
    </div>
  );
}
export function SearchBox({ value, onChange, placeholder = "Search..." }) {
  return (
    <label className="search-box">
      <Search size={18} />
      <input
        aria-label={placeholder}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
      />
    </label>
  );
}
export function Modal({ title, children, onClose, size = "" }) {
  const closeRef = useRef(null);
  const previous = useRef(document.activeElement);
  const onCloseRef = useRef(onClose);
  const closingRef = useRef(false);
  const closeTimer = useRef(null);
  const [closing, setClosing] = useState(false);
  const requestClose = useCallback(() => {
    if (closingRef.current) return;
    closingRef.current = true;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      onCloseRef.current();
      return;
    }
    setClosing(true);
    closeTimer.current = window.setTimeout(() => onCloseRef.current(), 210);
  }, []);
  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);
  useEffect(() => {
    const returnFocus = previous.current;
    closeRef.current?.focus();
    const onKey = (event) => {
      if (event.key === "Escape") requestClose();
      if (event.key === "Tab") {
        const focusable = [
          ...document.querySelectorAll(
            ".modal [href], .modal button:not(:disabled), .modal input:not(:disabled), .modal select:not(:disabled), .modal textarea:not(:disabled)",
          ),
        ];
        const first = focusable[0],
          last = focusable.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      window.clearTimeout(closeTimer.current);
      returnFocus?.focus?.();
    };
  }, [requestClose]);
  return (
    <div
      className={`modal-backdrop${closing ? " is-closing" : ""}`}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) requestClose();
      }}
    >
      <section
        className={`modal ${size}${closing ? " is-closing" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="modal-head">
          <h2>{title}</h2>
          <IconButton
            icon={X}
            label="Close dialog"
            onClick={requestClose}
            className="modal-close"
            buttonRef={closeRef}
          />
        </div>
        {children}
      </section>
    </div>
  );
}
export function PageHead({ eyebrow, title, description, action }) {
  return (
    <div className="page-head">
      <div>
        <div className="eyebrow">{eyebrow}</div>
        <h1>{title}</h1>
        {description && <p>{description}</p>}
      </div>
      {action && <div className="page-head-action">{action}</div>}
    </div>
  );
}
export function DemoNote({
  children = "Demo data · Changes are previews in this browser session and are not saved to a server.",
}) {
  return (
    <div className="demo-note">
      <Info size={16} />
      <span>{children}</span>
    </div>
  );
}
export function ProductArt({ product, size = "normal" }) {
  const Icon = icons[product?.icon] || Package;
  return (
    <div className={`product-art ${product?.icon || "generic"} ${size}`}>
      <Icon size={size === "large" ? 62 : 37} strokeWidth={1.35} />
    </div>
  );
}
export function ProductCard({ product, onOpen }) {
  return (
    <button className="product-card" onClick={() => onOpen(product)}>
      <ProductArt product={product} />
      <div className="product-card-body">
        <div className="product-meta">
          {product.category}
          <Badge tone={product.availableUnits ? "success" : "danger"}>
            {product.availableUnits ? "Available" : "Unavailable"}
          </Badge>
        </div>
        <h3>{product.name}</h3>
        <p>{product.description}</p>
        <div className="card-bottom">
          <span>
            <strong>{product.availableUnits}</strong> of {product.totalUnits}{" "}
            units available
          </span>
          <ChevronRight size={18} />
        </div>
      </div>
    </button>
  );
}
export function StatCard({ icon: Icon, label, value, sub, tone = "amber" }) {
  return (
    <div className="stat-card">
      <span className={`stat-icon ${tone}`}>
        <Icon size={22} />
      </span>
      <div>
        <div className="stat-value">{number(value)}</div>
        <div className="stat-label">{label}</div>
        {sub && <small>{sub}</small>}
      </div>
    </div>
  );
}
export function Loading() {
  return (
    <div className="loading">
      <RefreshCw size={22} className="spin" /> Loading demo data…
    </div>
  );
}
