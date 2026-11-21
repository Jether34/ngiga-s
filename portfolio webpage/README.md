# Recovered portfolio website

This folder contains the published static files recovered from the August 11, 2026 Cloudflare Worker version `5c93a736-904c-4712-8c9a-4056e460b442`. The original React source is not present in the Worker; `site/assets/index-Bv72GQ5d.js` is its compiled JavaScript bundle.

The `site` directory contains the deployable website. `preview.png` is a screenshot of the recovered version.

To deploy this portfolio to the existing `lingering-wave-20b9` Worker, run `npx wrangler deploy` from this folder while authenticated to the correct Cloudflare account. The Wrangler configuration serves only the `site` directory, so the README and screenshot are not public assets.

Original version URL: https://5c93a736-lingering-wave-20b9.garquejether681.workers.dev/
