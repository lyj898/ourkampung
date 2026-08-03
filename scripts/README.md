# Programmatic SEO — theme landing pages

This folder holds a small generator that turns a data file into SEO landing
pages, so the site can rank for long-tail searches like
"unicorn birthday party singapore" without paid ads.

## Files

| Path | Role |
|---|---|
| `data/themes.json` | The content for every theme (one object per page) |
| `scripts/Generate-ThemePages.ps1` | Reads the data, writes one `<slug>.html` per theme at the repo root, rebuilds `sitemap.xml`, and refreshes the card grid in `themes.html` |

## Run it

From the repo root, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Generate-ThemePages.ps1
```

It regenerates every theme page, the sitemap, and the `themes.html` hub grid.
No Node, no build step, no deploy change — the output is plain static HTML that
GitHub Pages serves directly.

## Add a new theme

1. Copy an existing object in `data/themes.json` and edit the fields:
   - `slug` — becomes the filename **and** the URL keyword. Keep the
     `<theme>-birthday-party-singapore` pattern.
   - `titleName`, `name`, `kicker`, `h1`, `metaDescription`, `intro`
   - `image` — path under `assets/` (ideally a 1200×630 image for social previews)
   - `ideas` (4), `palette` (4 × name/hex), `faqs` (3 × q/a), `related` (2–3 slugs)
2. If you want it in the hub grid, add a one-line tagline for its slug in the
   `$taglines` map inside `Generate-ThemePages.ps1`.
3. Re-run the script. Commit and push.

## Avoid thin content

Google penalises near-duplicate "doorway" pages. Every theme's `intro`,
`ideas`, `palette`, and `faqs` should be genuinely specific to that theme —
never just the same text with the name swapped. Each page already carries
`Service`, `FAQPage`, and `BreadcrumbList` structured data.

## Scaling to more page types

The same pattern works for other high-intent clusters — add a `data/*.json`
and a sibling generator:

- **Milestones** — `1st-birthday-party-singapore`, `full-month-celebration-singapore`, `100-days-celebration-singapore`
- **Locations** — `kids-party-venue-tampines`, `condo-function-room-birthday-party`, etc.
- **Services** — `balloon-decoration-singapore`, `birthday-party-magician-singapore`

## If you later move to a build tool (Astro/11ty)

This static-generation approach was chosen because Node isn't installed and the
site deploys straight from the repo root. If you install Node and want a proper
build pipeline (component reuse, auto-sitemap, dev preview), Astro is a clean
fit: move the shared header/footer into a layout component, keep
`data/themes.json` as the data source, and deploy `dist/` via a GitHub Action
(set **Settings → Pages → Source** to **GitHub Actions**). The content model
here (one JSON object per page) ports over directly.
