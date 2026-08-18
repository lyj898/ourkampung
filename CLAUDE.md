# Project Rules

## New pages/routes

When creating any new page or route, do both of the following **in the same change** as the page creation — never defer:

1. **Mobile responsive check** — verify layout at 375px, 768px, and 1024px widths: no horizontal overflow, tap targets sized appropriately, text/images scale correctly.
2. **Sitemap update** — pages under `scripts/` (`Generate-LandingPages.ps1`, `Generate-ThemePages.ps1`, `Generate-Articles.ps1`) auto-rebuild `sitemap.xml`; re-run the relevant generator instead of hand-editing. For any page added outside those generators, add a `<url>` entry to `sitemap.xml` directly, matching the existing format.

## Generator run order

`Generate-LandingPages.ps1` and `Generate-ThemePages.ps1` rebuild `sitemap.xml` from a
hardcoded core-page list that **omits `blog.html` and every article**. Running either one
last silently drops those URLs from the sitemap (55 → 47).

**Always finish a regeneration run with `Generate-Articles.ps1`** — it is the only generator
that merges all four data sets into the complete sitemap.

## Structured data

`data/business.json` is the **single source of truth** for the business entity. Do not
re-declare the business inline anywhere.

Every page emits exactly **one** `<script type="application/ld+json">` containing a single
`@graph`, in which:

- the business node is `https://ourkampung.com/#business` and the site node is `#website`
- page-level nodes reference them by `@id` (`provider`, `publisher`, `author`, `about`,
  `isPartOf`) rather than repeating name/url stubs
- per-page nodes use `<canonical-url>#webpage`, `#service`, `#article`, `#breadcrumb`, `#list`

Ownership:

| Pages | Owned by |
|---|---|
| services / locations / milestones clusters | `Generate-LandingPages.ps1` |
| theme pages | `Generate-ThemePages.ps1` |
| articles + `blog.html` | `Generate-Articles.ps1` |
| `index.html` + hand-maintained hubs (`services`, `themes`, `events`, `birthdays`, `how-it-works`, `plan`, `contact`) | `Update-StaticPageSchema.ps1` |

`Update-StaticPageSchema.ps1` reads each page's `<title>`, `<meta name="description">` and
`og:image` back out of its own `<head>`, so it never invents copy — edit the page, re-run it.
It is idempotent (strips its own `<!--SCHEMA:START/END-->` block plus any stray JSON-LD before
writing) and does **not** touch `sitemap.xml`.

Data conventions:

- **`areaServedPlace`** (optional, `locations.json`): set it on entries that are real
  Singapore towns so the page asserts `Place: "<Town>, Singapore"`. Leave it off for
  non-place entries (`At Home`, `Condo Function Rooms`) — they fall back to
  `Country: Singapore`.
- **`dateModified`** (optional, `articles.json`): falls back to `datePublished`. Set it when
  revising existing article copy so the freshness signal is real.
- When reading a `data/*.json` list in a new script, use the `Load` helper pattern the other
  generators use. A bare `@(Get-Content … | ConvertFrom-Json)` assignment nests the array one
  level deep in this PowerShell version; function output unrolling is what flattens it.

### Still missing (needs real values, do not invent)

`telephone`, `sameAs` (Instagram / Facebook / Google Business Profile), `openingHours`,
`logo` (no logo asset exists — the mark is inline SVG), and `aggregateRating` (only with
genuine reviews). The footer's Instagram link is still `href="#"`.
