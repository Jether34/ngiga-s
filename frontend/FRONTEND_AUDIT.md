# Frontend audit and handoff

Reviewed against the Frontend SRS v1.1 (20 November 2026) and the later forest-green palette and layered landing-page requests. The later user requests take precedence over the SRS's original amber visual reference. This audit covers the React frontend and fixture-backed service adapter; it does not certify backend behavior.

## SRS acceptance coverage

| ID | Frontend status |
| --- | --- |
| FE-01 | Public Home/About/Contact/Goal, student, and administrator routes and active states are present. Browser Back/Forward and deep-link refresh were smoke-tested. |
| FE-02 | Sign up and login use school email only; sign up has no role selector or phone field. |
| FE-03 | Find, Scan, and Borrow have separate labeled icon cards in the landing-page steps section. The existing layered hero artwork remains. |
| FE-04 | Required fields, local validation, busy/disabled states, draft legal agreement, and success/error feedback are present. Sign-up and contact validation were exercised in a browser. |
| FE-05 | Student catalog search/category filters, availability, loans, returns, overdue notice, activity, and loading/empty/error states are present. Search and product detail were exercised. |
| FE-06 | Camera/decoder states and manual code entry are present. Manual valid, invalid, and unavailable unit paths were exercised. Hardware camera permission paths require device testing. |
| FE-07 | Borrow review shows student, product, unit code/serial, borrow time, and due time. Due-time validation and demo confirmation were exercised. |
| FE-08 | Product management, filters/sort, unit list, low-stock report, and receive progress are present. Duplicate and accepted receive previews were exercised. |
| FE-09 | Issue and return modes, student/loan details, review, and Good/Needs Maintenance outcomes are present. Both preview paths were exercised. |
| FE-10 | Student history is scoped to the session identity and receipt file controls depend on artifact URLs. |
| FE-11 | Administrator overview, history, users, and settings routes and panels are present. Role navigation was exercised. |
| FE-12 | Centralized forest/emerald/beige tokens, Lucide icons, visible status words, and focused controls are present. |
| FE-13 | No page-level horizontal overflow was found in the sampled widths: 320px landing page; 390px role routes; 768px public, auth, and dashboard pages; and desktop public/role pages. Tables retain their own horizontal scrolling. |
| FE-14 | Demo labels and preview results explicitly state that changes are not persisted or emailed. |

## Verification performed

- `npm run lint`, `npm test`, and `npm run build` completed successfully. The four regression tests cover school email validation, unit lookup, sign-up preview data handling, and fixture inventory/loan consistency.
- Production preview returned the app for `/about` on direct request. A deployed static host still needs a client-route rewrite.
- Browser smoke checks covered public navigation and Back/Forward; student and administrator route menus; sign-up agreement and policy modal; contact validation; student search, modal, and borrow flow; receive duplicate/progress; issue and return previews; notification Escape behavior; and scan-tab arrow keys.
- The 10-second landing headline cycle and reduced-motion static headline were checked after the component was isolated to avoid rerendering the full hero on each character.
- Browser screenshots were reviewed at desktop and narrow-phone widths. Camera hardware, external email, and real receipt files were not available for end-to-end testing.

## Before a live release

1. Replace `demoService` fixture methods with authenticated APIs for accounts, catalog, inventory, loans, transactions, receipts, reports, and event subscriptions.
2. Enforce roles, student record scope, unique codes/serials, inventory consistency, and atomic issue/return operations on the server.
3. Supply approved Terms of Use, Privacy Policy, school branding/domains, real contact details, and institution loan policy.
4. Configure HTTPS for camera access and an SPA route fallback on the host; test camera permissions on target devices.
5. Add persistent automated browser tests against the real service adapter before production deployment. The current regression tests cover service and validation logic; they do not replace end-to-end tests.

## Finalization pass

- Hardened demo session parsing, account form failures, product and unit validation, scanning cleanup, and administrator/student preview error states.
- Replaced non-keyboard table row actions with focusable buttons and added a page error fallback.
- Split student and administrator routes into on-demand bundles. The landing bundle is smaller while role pages retain the same routes and controls.
- Rechecked light and dark appearance, administrator navigation, product dialog opening and Escape dismissal in the local preview. A narrow-screen live check was interrupted by concurrent computer input; the existing responsive audit above remains the recorded viewport coverage.
- `npm audit --audit-level=high` reported zero known vulnerabilities at the time of this pass. This is a dependency advisory check, not a security certification.

The frontend is suitable for review and backend integration. It is not a production borrowing service until these integrations and institutional details are supplied.
