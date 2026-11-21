# equip.campus frontend

React, JavaScript (JSX), regular CSS, Vite, and Lucide React implementation of the Student Equipment and Inventory Borrowing Management System frontend.

## Run locally

```bash
cd frontend
npm install
npm run dev
```

Open the local address printed by Vite, normally `http://localhost:5173`. For a production build, run `npm run build` and `npm run preview`. Run `npm run lint` for static checks.

## Demo access

The Log In page has **Student demo** and **Admin demo** buttons. These create an explicitly labeled in-browser demo session. Sample school accounts also accept the password `Demo123!`.

- Student: `alex.rivera@university.edu`
- Admin: `morgan.reyes@university.edu`
- Example item codes: `CAM-R50-001` (available), `CAM-R50-003` (borrowed), `CAM-R50-005` (maintenance)

All fixture data and workflow results are previews. Borrowing, receiving, issuing, returning, signup, product edits, profile edits, account status changes, and password validation do **not** persist to a server. Receipt file and email actions stay unavailable until a receipt service supplies real artifacts and delivery state. Refresh reloads fixture data.

## Configuration

Copy `.env.example` to `.env.local` and adjust the school name and permitted school email domains. The default `university.edu` is illustrative. Camera scanning uses the browser's `getUserMedia` and `BarcodeDetector` when available; manual code entry always remains available. Camera permission usually requires localhost or HTTPS.

## Integration points

`src/services/demoService.js` is the service boundary for authentication, catalog, unit lookup, loans, transactions, users, receipts, low-stock reporting, and future live-event subscriptions. Replace its fixture-backed method bodies with API requests that return the same `{ ok, data }` or `{ ok: false, error }` shape. Server authorization, unique unit codes, atomic issue and return operations, stock consistency, receipt generation, Gmail delivery, and live synchronization all require backend services.

## Project structure

- `src/App.jsx` — route and session composition
- `src/pages/` — public, student, and administrator pages and workflows
- `src/components/` — shared UI, role shell, item detail, and camera/manual capture
- `src/utils/domain.js` — display helpers and role navigation definitions
- `src/App.css` and `src/index.css` — visual tokens, surfaces, and responsive styling
- `src/data/fixtures.js` — demo models and example records
- `src/services/demoService.js` — replaceable service adapter

The supplied SRS is the requirements baseline. Its Appendix A is used for palette and composition; parcel language and phone authentication are intentionally excluded.
