import { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  ArrowRight,
  Boxes,
  CalendarClock,
  ClipboardList,
  History,
  PackagePlus,
  RotateCcw,
  ScanLine,
  Search,
  Settings2,
  Sparkles,
  UsersRound,
} from "lucide-react";

const studentTips = [
  { icon: Sparkles, title: "Need a hand?", description: "Scan a unit code or explore the equipment catalog.", action: "Start scanning", page: "scan" },
  { icon: Search, title: "Find equipment", description: "Browse available equipment and check its availability.", action: "Explore catalog", page: "home" },
  { icon: ScanLine, title: "Borrow with ease", description: "Scan an available item and choose your return date.", action: "Borrow now", page: "scan" },
  { icon: History, title: "Track your items", description: "View borrowed equipment and upcoming return dates.", action: "View history", page: "history" },
  { icon: CalendarClock, title: "Never miss a return", description: "Keep track of your expected return dates.", action: "Check returns", page: "history" },
  { icon: Settings2, title: "Manage your profile", description: "Update your information and account preferences.", action: "Open settings", page: "settings" },
];

const adminTips = [
  { icon: PackagePlus, title: "Register products", description: "Add equipment types and keep their details up to date.", action: "Open products", page: "products" },
  { icon: Boxes, title: "Monitor inventory", description: "Review product availability and individual unit status.", action: "View inventory", page: "products" },
  { icon: ScanLine, title: "Scan a unit", description: "Identify equipment quickly with its unit code.", action: "Start scanning", page: "scan" },
  { icon: ClipboardList, title: "Review transactions", description: "See borrowing activity and the people using campus gear.", action: "View history", page: "history" },
  { icon: RotateCcw, title: "Process returns", description: "Check active loans and record returned equipment.", action: "Process a return", page: "scan" },
  { icon: UsersRound, title: "Support students", description: "Review student accounts and their borrowing activity.", action: "Manage users", page: "users" },
];

const transitionMs = 380;

function readingDuration(tip) {
  const words = `${tip.title} ${tip.description} ${tip.action}`.trim().split(/\s+/).length;
  return Math.min(10000, Math.max(5000, 3000 + words * 180));
}

function useReducedMotion() {
  const [reduced, setReduced] = useState(() =>
    typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(media.matches);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  return reduced;
}

export function HelpCarousel({ role, navigate }) {
  const tips = role === "ADMIN" ? adminTips : studentTips;
  const reducedMotion = useReducedMotion();
  const [activeIndex, setActiveIndex] = useState(0);
  const [phase, setPhase] = useState("visible");
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const [timerVersion, setTimerVersion] = useState(0);
  const paused = hovered || focused;
  const pausedRef = useRef(paused);
  const remainingRef = useRef(readingDuration(tips[0]));
  const pendingIndexRef = useRef(null);

  useLayoutEffect(() => {
    pausedRef.current = paused;
  }, [paused]);

  useEffect(() => {
    if (phase !== "visible" || paused || reducedMotion) return undefined;

    const remaining = remainingRef.current;
    const started = performance.now();
    const timer = window.setTimeout(() => {
      remainingRef.current = 0;
      setPhase("exiting");
    }, remaining);

    return () => {
      window.clearTimeout(timer);
      if (pausedRef.current) {
        remainingRef.current = Math.max(0, remaining - (performance.now() - started));
      }
    };
  }, [activeIndex, phase, paused, reducedMotion, timerVersion]);

  useEffect(() => {
    if (phase !== "exiting") return undefined;
    if (pendingIndexRef.current === null && (paused || reducedMotion)) {
      const frame = window.requestAnimationFrame(() => {
        remainingRef.current = readingDuration(tips[activeIndex]);
        setPhase("visible");
      });
      return () => window.cancelAnimationFrame(frame);
    }

    const timer = window.setTimeout(() => {
      const next = pendingIndexRef.current ?? (activeIndex + 1) % tips.length;
      pendingIndexRef.current = null;
      remainingRef.current = readingDuration(tips[next]);
      setActiveIndex(next);
      setPhase("entering");
    }, transitionMs);
    return () => window.clearTimeout(timer);
  }, [activeIndex, phase, paused, reducedMotion, timerVersion, tips]);

  useEffect(() => {
    if (phase !== "entering") return undefined;
    const frame = window.requestAnimationFrame(() => setPhase("visible"));
    return () => window.cancelAnimationFrame(frame);
  }, [phase]);

  const selectTip = (index) => {
    remainingRef.current = readingDuration(tips[index]);
    if (reducedMotion || index === activeIndex) {
      pendingIndexRef.current = null;
      setActiveIndex(index);
      setPhase("visible");
    } else {
      pendingIndexRef.current = index;
      setPhase("exiting");
    }
    setTimerVersion((version) => version + 1);
  };

  const tip = tips[activeIndex];
  const Icon = tip.icon;

  return (
    <section
      className="sidebar-help"
      aria-label={`${role === "ADMIN" ? "Administrator" : "Student"} help tips`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocusCapture={(event) => {
        if (event.target.matches(":focus-visible")) setFocused(true);
      }}
      onBlurCapture={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) setFocused(false);
      }}
    >
      <div className={`help-slide help-slide-${phase}`} aria-live="off">
        <div className="help-heading">
          <Icon size={20} strokeWidth={1.9} aria-hidden="true" />
          <strong>{tip.title}</strong>
        </div>
        <p>{tip.description}</p>
        <button className="help-action" type="button" onClick={() => navigate(tip.page)}>
          {tip.action} <ArrowRight size={16} aria-hidden="true" />
        </button>
      </div>
      <div className="help-dots" role="group" aria-label="Choose a help tip" style={{ "--active-index": activeIndex }}>
        <span className="help-indicator" aria-hidden="true" />
        {tips.map((item, index) => (
          <button
            key={item.title}
            className={`help-dot${index === activeIndex ? " active" : ""}`}
            type="button"
            aria-label={`Show tip ${index + 1} of ${tips.length}: ${item.title}`}
            aria-pressed={index === activeIndex}
            onClick={() => selectTip(index)}
          />
        ))}
      </div>
    </section>
  );
}
