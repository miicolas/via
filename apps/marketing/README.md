# Marketing

Next.js marketing site for the monorepo.

## Structure

- `src/app/(marketing)` composes the public route.
- `src/constants` owns project metadata, page copy, navigation, and collection data.
- `src/components/ui` contains reusable visual and interaction modules.
- `src/components/layout` contains the shared marketing shell.
- `src/components/sections` contains data-driven page sections.

## Environment

`NEXT_PUBLIC_API_URL` — origin of `@via/api`, used by the coverage section to
read and cast city-demand votes (`GET`/`POST /public/city-demand`). It is public
because the vote is sent by the browser: proxying it through a route handler
would give every vote the same server address, and the API counts one voice per
address.

Outside production it defaults to `http://localhost:3000`; set it explicitly
when the API and this site share a port. Unset in production the map still
draws, the counters simply do not.

`VIA_SITE_CLIENT_KEY` — server-only shared secret sent as `x-via-client-key` on
the render-time read. The API answers first-party callers only: from the browser
this site is recognised by its origin, which the API lists in
`VIA_ALLOWED_ORIGINS`, but a server render has no origin to send. It must match
one of the API's `VIA_SITE_CLIENT_KEYS`, and it must never be prefixed
`NEXT_PUBLIC_` — that would ship it to every visitor.

`NEXT_PUBLIC_SITE_URL` — canonical public origin used by metadata and the
sitemap. Vercel's production URL is used automatically when available; local
development otherwise falls back to `http://localhost:3000`.

## Commands

```bash
bun run dev
bun run typecheck
bun run lint
bun run build
```
