# Project Rules

## New pages/routes

When creating any new page or route, do both of the following **in the same change** as the page creation — never defer:

1. **Mobile responsive check** — verify layout at 375px, 768px, and 1024px widths: no horizontal overflow, tap targets sized appropriately, text/images scale correctly.
2. **Sitemap update** — pages under `scripts/` (`Generate-LandingPages.ps1`, `Generate-ThemePages.ps1`, `Generate-Articles.ps1`) auto-rebuild `sitemap.xml`; re-run the relevant generator instead of hand-editing. For any page added outside those generators, add a `<url>` entry to `sitemap.xml` directly, matching the existing format.
