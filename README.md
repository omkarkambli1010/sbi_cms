# cms-website

Public marketing content rendered on the server. The browser receives HTML; it
never talks to the content API.

```
Browser
  └─ Next.js Server Component        src/app/page.tsx
       └─ server-only CMS service    src/server/cms/cms.service.ts
            └─ server-only transport src/server/http/serverFetch.ts
                 └─ Go API / CMS     (gated off — see CONTRACT.md)
```

## Status

**Live fetching is off.** Content resolves to typed fallback content until the
server-to-server security contract is agreed. Nothing is stubbed behind a fake
endpoint and no authentication has been invented — the open questions are in
[CONTRACT.md](./CONTRACT.md).

## Layout

| Path | Role |
| --- | --- |
| `src/app/page.tsx` | Async Server Component. Awaits page content, wraps the slow read in Suspense. |
| `src/server/cms/cms.types.ts` | Content contracts. Shared — types only, erased at build. |
| `src/server/cms/cms.config.ts` | `server-only`. Env, cache policy, the live-fetch gate. |
| `src/server/cms/cms.service.ts` | `server-only`. The only way page code reads content. |
| `src/server/cms/cms.fallback.ts` | `server-only`. Typed default content. |
| `src/server/http/serverFetch.ts` | `server-only`. Transport: timeout, cache mode, typed errors. No auth. |
| `src/components/cms/*` | Server Components, except `FaqAccordion.tsx`. |
| `src/components/cms/FaqAccordion.tsx` | The one Client Component — expand/collapse only, content via props. |

## How the requirements are enforced

**No browser-to-backend calls.** Reads happen in Server Components through a
`server-only` service. There is no client-side fetch of public content.

**Content in the initial HTML.** Verified against the built server: the hero,
features, insights and *all* FAQ answers — including collapsed ones — are in
the delivered HTML. The accordion toggles `hidden` rather than conditionally
rendering, so the text is crawler-visible without JavaScript.

**No `useEffect` for initial content.** There is none in the repository.

**Client Components only for interaction.** One file carries `"use client"`,
and it receives `items` as props.

**Nothing server-only in the client bundle.** Enforced by the `server-only`
package, not convention. Verified two ways: the built client chunks contain
none of `CMS_API_BASE_URL`, `/v1/pages/home`, `buildRequestHeaders`,
`CACHE_POLICY`, `isCmsConfigured` or `getCmsConfig`; and importing
`cms.config` from the client component fails the build with
`'server-only' cannot be imported from a Client Component module`.

**Typed services.** `getHomePageContent()` and `getInsightsContent()` return
`ContentResult<T>`, reporting whether the payload came from `cms` or
`fallback`. Upstream JSON is structurally validated before it reaches a
component.

**Cache policy.** Declared per content type in `CACHE_POLICY` and passed to
`next.revalidate`, with `revalidate: 0` mapping to `no-store`. Reads are tagged
(`cms:home`, `cms:insights`) so on-publish invalidation is ready. Values are
placeholders pending approval.

**Suspense for slow data.** The insights listing does its own read inside its
own boundary, so the rest of the page paints immediately. There is also a
route-level `loading.tsx`.

## Why not reuse the existing `apiClient`

The marketing site's axios client attaches interceptors that read
`window.sessionStorage` and `window.localStorage` for `clientid` and `token`
(`src/services/api/apiInterceptors.ts` in that repo). Those globals do not exist
on the server, so it cannot be imported into a Server Component. `serverFetch`
is the server-side equivalent: transport only, no browser assumptions.

## Running

```bash
npm install
npm run dev        # http://localhost:3001
npm run build && npm start
npm run typecheck
```

Port 3001 so it does not collide with the marketing site on 3000.

Copy `.env.example` to `.env.local`. Leaving `CMS_API_BASE_URL` unset keeps
fallback content — which is the intended state today.
