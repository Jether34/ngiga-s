# Avelino's ENcoRE webpage

React and Vite frontend for ENcoRE student and administrator accounts. The live site is [ngiga-avelino-demo.garquejether681.workers.dev](https://ngiga-avelino-demo.garquejether681.workers.dev/).

## Local development

```bash
npm install
npm run dev
npm test
npm run lint
npm run build
```

The local Vite origin (`http://localhost:5173`) and the deployed Cloudflare origin are allowed by the ENcoRE API. Browser requests go directly to `https://pns-sysnnova.cloud/stockroom-api` so the existing login verification can see each visitor's IP address. Do not put account secrets in Vite environment variables.

## Accounts and data

`src/services/apiService.js` maps the ENcoRE C++ API to the webpage's student and admin screens. Sign-up, login verification, password reset, equipment, physical units, loans, receipts, student accounts, and admin actions use the ENcoRE MySQL database. The JWT is stored in browser session storage and checked with `/me` when a session resumes. Student and admin permissions are enforced by the API.

The public landing illustration still uses sample product artwork from `src/data/fixtures.js`; signed-in pages do not use those records. Theme and browser notification preferences are local to the browser. The public contact form is a message preview and is not a support ticket service.

Camera scanning needs HTTPS or localhost and browser camera permission. Manual item code entry remains available. Receipt PDF and PNG files are generated in the browser from real ENcoRE loan records.

## Deployment

`npm run build` generates `dist/`. `npx wrangler deploy` publishes the Cloudflare Worker assets configured in `wrangler.jsonc`. The host must serve `index.html` for client routes such as `/login`, `/student/home`, and `/admin/products`. The ENcoRE API must allow the deployed origin for CORS. Keep administrator privileges and database credentials on the API, never in the frontend bundle.
