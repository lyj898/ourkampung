# Project Rules — OurKampung

ourkampung.com is a **guide-only** site about running a Singapore home: moving, moving into a new
home, ending a tenancy, decluttering and disposal, repairs and upkeep. Since the 5 Oct 2026 family
revamp (`../jtc-family/briefs/family-revamp.md`) it is also the **mother site** of the family: the front
door to its sister sites, all run by the team behind Junk to Clear. It takes no bookings and gives no
quotes; its form is "Contact the editors" and sends GA4 `editor_message`, never `generate_lead`.

Shared rules for the whole JTC family of sites (lanes, link rules, brand facts, shared facts). They win
over anything below: @../jtc-family/PORTFOLIO.md

Until 2026-09-28 this domain was a kids' party-planning site. None of that content remains, and
old party URLs 404 on purpose (see **History**).

## Never break analytics or Search Console

The user explicitly does not want to set these up again.

- **GA4** measurement ID `G-8XGK5F86ZX` must be on every page, including `404.html`.
- **Search Console** verification tag (`google-site-verification`,
  token `HjvZuJxCuygLjDF7qlHp54oWb6OJQmloOGrro1TWqGs`) must stay on the homepage. The
  `sc-domain:ourkampung.com` property is DNS-verified as well, but the tag is a second
  verification — removing it can un-verify a property.
- Both values live in `data/site.json`. `scripts/Build-Site.ps1` **refuses to build** if either
  changes, and checks every output page for the GA4 tag. Change them only deliberately, and update
  the expected values in the build script in the same commit.
- Keep `CNAME`, `robots.txt` and the `/sitemap.xml` path unchanged — the sitemap URL is the one
  submitted in Search Console.

## How the site is built

One command builds everything — every page, `sitemap.xml` and `OWNER-INPUT.md`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Build-Site.ps1
```

| Source | Holds |
|---|---|
| `data/site.json` | site settings, GA4 ID, verification token, form endpoint |
| `data/organization.json` | the OurKampung `Organization` node — single source of truth |
| `data/brands.json` | Junk to Clear and the sister sites (`"sister"`: footer order, service or guide, when to use it), and every deep link to them |
| `data/sources.json` | official sources guides cite (HDB, ICA, NEA, SP, CEA, ALBA) |
| `data/hubs.json` | the five life-event hubs |
| `data/guides.json` | guide metadata, FAQs, related guides, "get help" links |
| `data/pages.json` | home, about, contact, the moving planner, 404 |
| `content/{guides,hubs,pages}/*.html` | the copy itself |

**Never hand-edit generated output** — `index.html`, `404.html`, the hub and guide folders,
`tools/`, `about/`, `contact/`, `sitemap.xml`, `OWNER-INPUT.md`. Edit the source and rebuild.

Content files link through tokens, which the build resolves and validates. An unknown token fails
the build, so a broken internal link cannot ship:
`{{guide:<slug>}}` `{{hub:<slug>}}` `{{page:<id>}}` `{{src:<key>}}` `{{brand:<id>/<key>}}`,
plus `{{illo:<name>}}` (an illustration `<img>`) and `{{icon:<name>}}` (an icon from `$icons` in the
build script).
Never hard-code an internal path or a sister-site URL in content — add it to the data files.

If the build warns about stale `.html` files, delete them; GitHub Pages will keep serving them.

`_config.yml` stops Jekyll (which GitHub Pages runs on this repo) publishing `CLAUDE.md`,
`OWNER-INPUT.md`, `content/`, `data/` and `scripts/`. Without it, Jekyll renders `.md` files into
public web pages — `CLAUDE.md` was live at `/CLAUDE.html` until the 2026-09-28 rebuild. Anything new
that shouldn't be public must be added to that list.

## New pages

When creating any page, in the same change:

1. **Mobile check** at 375px, 768px and 1024px: no horizontal overflow, tap targets of 44px or
   more, text and images scaling correctly. The nav collapses at 1024px and below.
2. **Sitemap** — handled by the build; never hand-edit `sitemap.xml`.

To add a guide: add an entry to `data/guides.json`, add its slug to its hub's `guides` list in
`data/hubs.json`, write `content/guides/<slug>.html`, rebuild.

## Design

Warm and neighbourly rather than editorial: flat illustrations of HDB estates, a pastel colour per
hub, and short copy on every page except the guides themselves.

- **Illustrations** live in `assets/illo/*.svg`: `hero` (the estate scene on the homepage and About),
  one per hub named after its slug, `planner`, and `skyline` (the footer strip, used from CSS). They
  are hand-written flat SVG in the site palette — no stock images, no photos of people. Each root
  `<svg>` needs `width` and `height`, which the build copies onto the `<img>` so nothing shifts as it
  loads. `{{illo:<name>}}` adds the cache-busting hash.
- **The hero's ground is `--surface-alt`** (`#EFE8DB`), so the scene stands on the section below it.
  Change one and you must change the other.
- **Hub colours** are CSS classes `.hub-<slug>` setting `--hub-tint`, `--hub-soft` and `--hub-deep`.
  Guide and hub pages carry the class on `<body>`; tiles and cards carry their own. Each family site
  keeps one colour and one icon everywhere (`$brandHue` and `$brandIcon` in the build script).
  `--hub-deep` is text-safe on `--hub-tint`; check contrast before adding a colour.
- **"At a glance" tiles** (`glance` in `data/guides.json`) sit at the top of each guide's short
  answer. `type` is `facts` or `steps`. Every tile must restate something the short answer already
  says — never a new number or claim.
- **Keep the guide bodies long.** "Less wordy" applies to the homepage, hubs and page chrome. The
  guides' depth is what separates them from the thin pages that got the site de-indexed; make them
  scannable (glance tiles, checklist rows, TOC chips) rather than shorter.
- **Hub pages** open with a "Where to start" list — `<ol class="steps">` in `content/hubs/`, three
  items of a sentence or two each.

## Content rules

**Link routing.** Send each need to the specialist brand, never to two brands for one job:

| Reader needs | Link to |
|---|---|
| Moving within Singapore | HomeToMoved |
| Cleaning | HomeToClean |
| Disposal / clearing | Junk to Clear |
| Pest control | PestToClear |
| Aircon | AirconToCool |
| Handyman jobs | BrokenToFixed |
| Renovation questions | SpaceToReno, named as a sister guide (add it once it's live) |

Don't link SkillsToFix: it's Junk to Clear's cross-sell site, and the family links its own pest,
aircon and handyman sites instead (5 Oct 2026). PORTFOLIO.md's link table wins if this one drifts.

- **Contextual links in the guides.** Link a family site where the guide covers something it does,
  mostly in each guide's "Need a hand with this?" box. (See also the cross-site linking rule in the
  user's global CLAUDE.md.)
- **Family links, the one sitewide exception.** The footer's "Sister sites" column, the homepage's
  "Sister sites" tiles and `/our-sites/` link every family site, generated from `"sister"` in
  `data/brands.json`. They use the site name as link text and `rel="nofollow"` — they're for readers,
  not rankings. Never `noreferrer` anywhere: it hides the visit from the sister site's GA4, and the
  build fails on it.
- **Always disclose** that OurKampung is run by the same team. Never publish "best of" lists or
  rank our own businesses against competitors.
- **Don't compete with Junk to Clear's blog.** It already covers bulky-item disposal, decluttering
  before a move, hiring movers and choosing a disposal company. Link those as `furtherReading`
  on a hub rather than writing rival guides.
- **No permutation pages** — no page per town, per theme, or per service × area. The site was
  de-indexed in August 2026 for exactly that (see **History**). Local detail belongs as a
  section inside a guide.
- **No invented facts.** Don't state prices, durations, deposit amounts or statistics we can't
  source. Mark the spot with `<!-- OWNER-INPUT: what would help -->` instead; the build strips
  these and lists them in `OWNER-INPUT.md` for the owner. Never fabricate reviews or ratings.
- **Cite official sources through `data/sources.json`.** HDB, ICA, SP Group and CEA deep links
  returned 404 when checked, so those point at agency homepages; NEA's e-waste, dengue and pest
  control pages and ALBA have stable deep links. Re-check any deep link before adding it.
- **Hedge what varies.** Tenancy agreements, condo house rules and renovation contracts differ —
  say "many", "usually", "check yours", rather than stating one rule.
- Open each guide with a `<div class="answer">` "The short answer" block — the direct-answer
  pattern AI assistants and search features extract.

## Structured data

Every page except `404.html` emits exactly one `<script type="application/ld+json">` with a single
`@graph`. The Organization node is `https://ourkampung.com/#organization` and the site node is
`#website`; page nodes reference them by `@id`. Per-page ids: `<canonical>#webpage`, `#article`,
`#breadcrumb`, `#list`, `#app`. Guides are credited to the Organization until a named author
exists — don't invent one.

## PowerShell 5.1 gotchas (the build runs on Windows PowerShell)

- Read `data/*.json` lists through the `Load` helper. A bare `@(Get-Content … | ConvertFrom-Json)`
  assignment nests the array one level deep; function-output unrolling is what flattens it.
- `@($genericList)` inside a `[pscustomobject]@{…}` literal throws "Argument types do not match".
  Use `$list.ToArray()`.
- `String.Replace` has no (string, char) overload — pass two strings.
- `$home` is a read-only automatic variable (`$HOME`). Don't use it as a variable name.

## History

- **Mid-July 2026:** launched as a kids' party-planning site, built from templated
  programmatic-SEO pages.
- **August 2026:** Google de-indexed most of it — 48 of 55 pages not indexed, 25 never crawled —
  with no manual action, no security issue and no technical fault. The per-town and per-theme
  pages averaged 279–311 words with 42% vocabulary overlap: boilerplate with the noun swapped.
  Only the hubs and the substantive articles stayed indexed.
- **2026-09-28:** rebuilt from scratch as this guide. Every party URL was retired. They 404 rather
  than redirect, because pointing party pages at home-services pages would be an irrelevant
  redirect, which Google treats as a soft 404. Expect those URLs to show as "Not found (404)" in
  Search Console for a while — that's intended.
