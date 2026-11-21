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

Profile pictures are validated, resized to at most 256 pixels, and stored in this browser's local storage for the current demo account. Theme preference is also stored locally; System default follows the device setting. Neither preference syncs to a server or another device.

## Configuration

Copy `.env.example` to `.env.local` and adjust the school name and permitted school email domains. The default `university.edu` is illustrative. Camera scanning uses the browser's `getUserMedia` and `BarcodeDetector` when available; manual code entry always remains available. Camera permission usually requires localhost or HTTPS.

## Integration points

`src/services/demoService.js` is the service boundary for authentication, catalog, unit lookup, loans, transactions, users, receipts, low-stock reporting, and future live-event subscriptions. Replace its fixture-backed method bodies with API requests that return the same `{ ok, data }` or `{ ok: false, error }` shape. Server authorization, unique unit codes, atomic issue and return operations, stock consistency, receipt generation, Gmail delivery, and live synchronization all require backend services.

## Deployment preparation

- Run `npm run lint` and `npm run build`; publish the generated `dist/` directory when deploying the frontend.
- Configure the host to serve `index.html` for client routes such as `/about`, `/login`, `/student/home`, and `/admin/products`. Vite preview supplies this fallback locally; a static host needs an equivalent rewrite.
- `VITE_SCHOOL_NAME` and `VITE_SCHOOL_DOMAINS` are embedded at build time. Set them before building, and rebuild after changing them. Do not put secrets in `VITE_` variables.
- Serve over HTTPS for camera access outside localhost. Manual item-code entry remains available when camera permissions or `BarcodeDetector` are unavailable.
- Replace the demo service with authenticated APIs before accepting real accounts or inventory transactions. The current in-browser session, local validations, contact preview, and fixture data are not production persistence or authorization.
- Have the institution review and replace the draft Terms of Use, Privacy Policy, sample contact details, and school email domain before public launch.
- The interface uses Google Fonts with local font fallbacks. If external font requests are restricted, self-host the fonts or use the fallbacks.

## Project structure

- `src/App.jsx` — route and session composition
- `src/pages/` — public, student, and administrator pages and workflows
- `src/components/` — shared UI, role shell, item detail, and camera/manual capture
- `src/utils/domain.js` — display helpers and role navigation definitions
- `src/App.css` and `src/index.css` — visual tokens, surfaces, and responsive styling
- `src/data/fixtures.js` — demo models and example records
- `src/services/demoService.js` — replaceable service adapter

The supplied SRS is the requirements baseline. Its Appendix A is used for palette and composition; parcel language and phone authentication are intentionally excluded.
