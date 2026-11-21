# equip.campus frontend

React, JavaScript (JSX), regular CSS, Vite, and Lucide React implementation of the Student Equipment and Inventory Borrowing Management System frontend.

## Run locally

```bash
cd "avelino's webpage"
npm install
npm run dev
```

Open the local address printed by Vite, normally `http://localhost:5173`. For a production build, run `npm run build` and `npm run preview`. Run `npm run lint` for static checks.

## Cloudflare deployment

This is a Vite application. Deploy the **built `dist` directory**, not the source folder. The source `index.html` references `/src/main.jsx`, which a browser cannot run directly. The Worker configuration in `wrangler.jsonc` serves `./dist` and falls back to `index.html` for application routes.

This copy deploys to its own `ngiga-avelino-demo` Worker. The recovered portfolio remains on the separate `lingering-wave-20b9` Worker.

For the `Jether` branch of `ngiga-s`, set these Cloudflare **Workers Builds** settings:

| Setting | Value |
| --- | --- |
| Production branch | `Jether` |
| Root directory | `avelino's webpage` |
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |

Cloudflare must install the npm dependencies before the build. From a local checkout, the equivalent commands are `npm ci`, `npm run build`, then `npx wrangler deploy`, all run inside `avelino's webpage`.

If deploying the original `Avelino` branch instead, its root directory is `frontend`. Copy the same `wrangler.jsonc` into that directory before using Workers Builds. For **Cloudflare Pages** rather than Workers, use the same branch and root directory, build command `npm run build`, and build output directory `dist`.

If uploading files manually in the Cloudflare dashboard, select the contents of `dist` after building. Uploading the project source creates a blank page because the JSX and CSS have not been bundled.

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
