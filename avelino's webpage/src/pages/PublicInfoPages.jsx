import { useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Boxes,
  CalendarCheck2,
  ClipboardList,
  Clock3,
  Mail,
  MapPin,
  PackageCheck,
  RotateCcw,
  Send,
  ShieldCheck,
  Sparkles,
  UsersRound,
} from "lucide-react";
import { Field } from "../components/ui";
import { SCHOOL_NAME } from "../data/fixtures";
import { PublicFooter, PublicHeader } from "./PublicPages";

function InfoLayout({ navigate, current, eyebrow, title, intro, children }) {
  return (
    <div className="welcome-page info-page">
      <PublicHeader navigate={navigate} current={current} />
      <main className="info-main">
        <button className="info-home-link" type="button" onClick={() => navigate("/")}>
          <ArrowLeft size={17} /> Back to home
        </button>
        <div className="info-hero">
          <span className="pill"><Sparkles size={15} /> Made for campus life</span>
          <span className="eyebrow">{eyebrow}</span>
          <h1>{title}</h1>
          <p>{intro}</p>
        </div>
        {children}
      </main>
      <PublicFooter />
    </div>
  );
}

function InfoCard({ icon: Icon, title, children }) {
  return (
    <article className="info-card">
      <span className="step-icon"><Icon size={25} /></span>
      <h2>{title}</h2>
      <p>{children}</p>
    </article>
  );
}

export function AboutPage({ navigate }) {
  return (
    <InfoLayout
      navigate={navigate}
      current="/about"
      eyebrow="ABOUT US"
      title="Good ideas need the right tools."
      intro="equip.campus brings the equipment catalog, borrowing steps, and loan details into one clear workspace for students and equipment administrators."
    >
      <section className="info-feature">
        <div>
          <span className="eyebrow">WHY WE EXIST</span>
          <h2>Less time managing equipment. More time creating.</h2>
          <p>
            Students can discover available gear, identify the exact unit with a
            code, and keep track of return dates. Administrators can manage
            inventory, review activity, and see which items are in circulation.
          </p>
          <button className="button" onClick={() => navigate("/signup")}>
            Get started <ArrowRight size={17} />
          </button>
        </div>
        <div className="info-feature-art" aria-hidden="true">
          <span><Boxes size={64} strokeWidth={1.3} /></span>
          <span><UsersRound size={28} /></span>
          <span><PackageCheck size={29} /></span>
        </div>
      </section>
      <div className="info-card-grid">
        <InfoCard icon={UsersRound} title="For students">
          Find equipment for coursework and projects, review loans, and plan returns from one place.
        </InfoCard>
        <InfoCard icon={ClipboardList} title="For administrators">
          Keep product and unit records organized while monitoring borrowing and return activity.
        </InfoCard>
      </div>
    </InfoLayout>
  );
}

export function GoalPage({ navigate }) {
  return (
    <InfoLayout
      navigate={navigate}
      current="/goal"
      eyebrow="OUR GOAL"
      title="Make every borrow easier to manage."
      intro="Our goal is a straightforward equipment journey, from finding an item to checking it back in, with useful information for everyone involved."
    >
      <div className="info-card-grid goal-grid">
        <InfoCard icon={PackageCheck} title="Simplify borrowing">
          Help students find suitable equipment, check availability, scan a unit, and review each request clearly.
        </InfoCard>
        <InfoCard icon={Boxes} title="Track inventory">
          Give administrators a clear view of products, individual units, status, and borrowing history.
        </InfoCard>
        <InfoCard icon={RotateCcw} title="Support timely returns">
          Keep due dates and active loans visible so students can return items and staff can process them smoothly.
        </InfoCard>
      </div>
      <section className="info-goal-banner">
        <span className="step-icon"><ShieldCheck size={26} /></span>
        <div>
          <h2>A shared view of what matters</h2>
          <p>Clear records and simple steps help campus equipment stay accessible for the next student who needs it.</p>
        </div>
      </section>
    </InfoLayout>
  );
}

const emptyContact = { name: "", email: "", subject: "", message: "" };

export function ContactPage({ navigate }) {
  const [form, setForm] = useState(emptyContact);
  const [errors, setErrors] = useState({});
  const [submitted, setSubmitted] = useState(false);

  const update = (key, value) => {
    setForm((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: "" }));
    setSubmitted(false);
  };

  const submit = (event) => {
    event.preventDefault();
    const next = {};
    if (form.name.trim().length < 2) next.name = "Enter your name.";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim()))
      next.email = "Enter a valid email address.";
    if (form.subject.trim().length < 3) next.subject = "Enter a subject.";
    if (form.message.trim().length < 10)
      next.message = "Enter a message of at least 10 characters.";
    setErrors(next);
    if (Object.keys(next).length === 0) setSubmitted(true);
  };

  return (
    <InfoLayout
      navigate={navigate}
      current="/contact"
      eyebrow="CONTACT US"
      title="We'd love to hear from you."
      intro="Questions about equipment, borrowing, or returns? Use the contact details below or prepare a message with the form."
    >
      <div className="contact-layout">
        <section className="contact-details" aria-label="Contact information">
          <h2>Get in touch</h2>
          <p>These are sample details for the frontend demo. Your institution can replace them when the contact service is connected.</p>
          <div className="contact-detail"><span><Mail size={20} /></span><div><strong>Email</strong><small>equipment@university.edu</small></div></div>
          <div className="contact-detail"><span><MapPin size={20} /></span><div><strong>Equipment office</strong><small>{SCHOOL_NAME}, Main Campus</small></div></div>
          <div className="contact-detail"><span><Clock3 size={20} /></span><div><strong>Sample office hours</strong><small>Monday–Friday, 8:00 AM–5:00 PM</small></div></div>
          <div className="contact-note"><CalendarCheck2 size={18} /> For an active loan, check its due date in your student workspace.</div>
        </section>
        <section className="contact-form-card" aria-label="Contact form">
          <h2>Send a message</h2>
          <p>Fill in the details below to preview your message.</p>
          <form onSubmit={submit} noValidate>
            <div className="contact-form-row">
              <Field label="Your name" error={errors.name} required>
                <input value={form.name} onChange={(event) => update("name", event.target.value)} autoComplete="name" maxLength={80} aria-invalid={Boolean(errors.name)} placeholder="Your name" />
              </Field>
              <Field label="Email address" error={errors.email} required>
                <input type="email" value={form.email} onChange={(event) => update("email", event.target.value)} autoComplete="email" maxLength={120} aria-invalid={Boolean(errors.email)} placeholder="you@university.edu" />
              </Field>
            </div>
            <Field label="Subject" error={errors.subject} required>
              <input value={form.subject} onChange={(event) => update("subject", event.target.value)} maxLength={120} aria-invalid={Boolean(errors.subject)} placeholder="How can we help?" />
            </Field>
            <Field label="Message" error={errors.message} required>
              <textarea rows="5" value={form.message} onChange={(event) => update("message", event.target.value)} maxLength={2000} aria-invalid={Boolean(errors.message)} placeholder="Tell us a little more..." />
            </Field>
            {submitted && (
              <div className="contact-success" role="status">
                <PackageCheck size={19} /> Your message passed local validation. No email was sent; delivery requires a connected contact service.
              </div>
            )}
            <button className="button" type="submit"><Send size={17} /> Preview message</button>
          </form>
        </section>
      </div>
    </InfoLayout>
  );
}
