<#
  Generate-LandingPages.ps1
  --------------------------------------------------------------
  Programmatic SEO generator for the milestone / service / location
  landing-page clusters. Same model as Generate-ThemePages.ps1:
  one JSON object per page -> one <slug>.html at the repo root.

  Reads   : data/milestones.json, data/services.json, data/locations.json
            (and data/themes.json, for cross-linking + the sitemap)
  Writes  : <slug>.html  (one per cluster entry)
  Rebuilds: sitemap.xml   (core + themes + all clusters) -- the complete map

  Usage (from anywhere):
      powershell -ExecutionPolicy Bypass -File scripts/Generate-LandingPages.ps1

  Add a page by adding an object to the relevant data/*.json, then re-run.
#>

$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$origin  = 'https://ourkampung.com'
$lastmod = '2026-08-03'

function Esc([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return '' }
    return ($s -replace '&(?!amp;|lt;|gt;|quot;|#\d+;|#x[0-9a-fA-F]+;)', '&amp;')
}
function Load([string]$name) {
    $p = Join-Path $repo "data/$name"
    if (Test-Path $p) { return @(Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}

# Cluster definitions: data file + the label used for the highlights section
# + breadcrumb parent (empty crumbUrl => 2-level Home > page).
$collections = @(
    @{ file = 'milestones.json'; heading = 'What we take care of';        crumbName = '';         crumbUrl = '' },
    @{ file = 'services.json';   heading = "What's included";             crumbName = 'Services'; crumbUrl = 'services.html' },
    @{ file = 'locations.json';  heading = 'How we make it effortless';   crumbName = '';         crumbUrl = '' }
)

# Global slug -> entry lookup across ALL clusters (incl. themes) so related
# cards can resolve names/images regardless of which cluster they live in.
$all = @()
$all += Load 'themes.json'
foreach ($c in $collections) { $all += Load $c.file }
$lookup = @{}
foreach ($x in $all) { if ($x -and $x.slug) { $lookup[$x.slug] = $x } }

$ga = @'
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-8XGK5F86ZX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-8XGK5F86ZX');
</script>
'@

$header = @'
<header class="header">
  <div class="wrap nav">
    <a href="index.html" class="brand" aria-label="OurKampung home"><svg class="logo-mark" viewBox="0 0 40 40" fill="none"><path d="M20 4c2.2 5.6 5.1 8.5 10.7 10.7C25.1 16.9 22.2 19.8 20 25.4 17.8 19.8 14.9 16.9 9.3 14.7 14.9 12.5 17.8 9.6 20 4z" fill="currentColor"/><circle cx="30.5" cy="28" r="3" fill="#B0663F"/><circle cx="10.5" cy="30" r="2.2" fill="#B79A5B"/></svg><span class="logo-txt">Our<em>Kampung</em></span></a>
    <nav aria-label="Primary"><ul class="nav-links">
      <li><a href="birthdays.html">Kids Birthdays</a></li>
      <li><a href="services.html">Services</a></li>
      <li><a href="themes.html">Themes</a></li>
      <li><a href="events.html">Other Events</a></li>
      <li><a href="how-it-works.html">How It Works</a></li>
    </ul></nav>
    <div class="nav-cta"><a class="btn btn-ghost" href="contact.html">Contact</a><a class="btn btn-primary" href="plan.html">Start Planning</a></div>
    <button class="burger" aria-label="Menu"><span></span><span></span><span></span></button>
  </div>
</header>
<div class="mobile-menu"><a href="birthdays.html">Kids Birthdays</a><a href="services.html">Services</a><a href="themes.html">Themes</a><a href="events.html">Other Events</a><a href="how-it-works.html">How It Works</a><a href="contact.html">Contact</a><a class="btn btn-primary" href="plan.html">Start Planning</a></div>
'@

$footer = @'
<footer class="footer"><div class="wrap">
  <div class="footer-grid">
    <div class="footer-about"><a href="index.html" class="brand"><svg class="logo-mark" viewBox="0 0 40 40" fill="none"><path d="M20 4c2.2 5.6 5.1 8.5 10.7 10.7C25.1 16.9 22.2 19.8 20 25.4 17.8 19.8 14.9 16.9 9.3 14.7 14.9 12.5 17.8 9.6 20 4z" fill="currentColor"/><circle cx="30.5" cy="28" r="3" fill="#B0663F"/><circle cx="10.5" cy="30" r="2.2" fill="#B79A5B"/></svg><span class="logo-txt">Our<em>Kampung</em></span></a><p>Singapore's all-in-one concierge for beautifully effortless children's parties.</p><a class="btn btn-primary" href="plan.html">Start Planning</a></div>
    <div><h4>Explore</h4><ul><li><a href="birthdays.html">Kids Birthdays</a></li><li><a href="services.html">Services</a></li><li><a href="themes.html">Themes</a></li><li><a href="events.html">Other Events</a></li></ul></div>
    <div><h4>Company</h4><ul><li><a href="how-it-works.html">How It Works</a></li><li><a href="plan.html">Plan Your Party</a></li><li><a href="blog.html">Guides</a></li><li><a href="contact.html">Contact</a></li></ul></div>
    <div><h4>Get In Touch</h4><ul><li><a href="contact.html">Send us a message</a></li><li><span style="color:var(--muted);font-size:var(--text-sm)">Islandwide &middot; Singapore</span></li></ul></div>
  </div>
  <div class="footer-bottom"><p>&copy; 2026 OurKampung. All rights reserved. &middot; ourkampung.com</p><div class="social"><a href="#" aria-label="Instagram"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor"/></svg></a></div></div>
</div></footer>
<script src="js/main.js"></script>
'@

$scopedCss = @'
<style>
  .th-prose{max-width:760px;margin:1.25rem auto 0;text-align:center;color:var(--muted);font-size:var(--text-lg)}
  .th-figure{margin:2.75rem auto 0;max-width:980px;border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow-md)}
  .th-ideas{list-style:none;display:grid;gap:1rem;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));padding:0;margin-top:2rem}
  .th-ideas li{background:var(--surface);border:1px solid var(--border-soft);border-radius:var(--radius);padding:1.1rem 1.25rem 1.1rem 2.6rem;box-shadow:var(--shadow-sm);position:relative}
  .th-ideas li::before{content:"";position:absolute;left:1.2rem;top:1.55rem;width:9px;height:9px;border-radius:50%;background:var(--gold)}
  .th-faq-wrap{max-width:780px;margin:2rem auto 0}
  .faq{background:var(--surface);border:1px solid var(--border-soft);border-radius:var(--radius);margin-bottom:.75rem;overflow:hidden}
  .faq summary{cursor:pointer;padding:1.05rem 1.35rem;font-family:var(--font-display);font-size:var(--text-lg);list-style:none;display:flex;justify-content:space-between;gap:1rem}
  .faq summary::-webkit-details-marker{display:none}
  .faq summary::after{content:"+";color:var(--gold);font-weight:400}
  .faq[open] summary::after{content:"\2013"}
  .faq div{padding:0 1.35rem 1.2rem;color:var(--muted)}
</style>
'@

$template = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
{{GA}}
<title>{{TITLE}}</title>
<meta name="description" content="{{DESC}}">
<link rel="canonical" href="{{ORIGIN}}/{{SLUG}}.html">
<meta name="theme-color" content="#7E8A6E">
<meta property="og:site_name" content="OurKampung">
<meta property="og:locale" content="en_SG">
<meta property="og:type" content="website">
<meta property="og:url" content="{{ORIGIN}}/{{SLUG}}.html">
<meta property="og:title" content="{{TITLE}}">
<meta property="og:description" content="{{DESC}}">
<meta property="og:image" content="{{ORIGIN}}/{{IMG}}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{{TITLE}}">
<meta name="twitter:description" content="{{DESC}}">
<meta name="twitter:image" content="{{ORIGIN}}/{{IMG}}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400..600;1,9..144,400..500&display=swap" rel="stylesheet">
<link href="https://api.fontshare.com/v2/css?f[]=satoshi@300,400,500,700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="css/style.css">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath d='M16 3l3.6 8.2L28 12l-6 6 1.5 8.5L16 22.5 8.5 26.5 10 18l-6-6 8.4-.8z' fill='%237E8A6E'/%3E%3C/svg%3E">
{{JSONLD}}
{{CSS}}
</head>
<body>
{{HEADER}}
<main>
<section class="page-hero">
  <div class="wrap">
    <span class="kicker center">{{KICKER}}</span>
    <h1>{{H1}}</h1>
    <p class="th-prose">{{INTRO}}</p>
    <figure class="th-figure"><img src="{{IMG}}" alt="{{NAME}} by OurKampung Singapore"></figure>
  </div>
</section>

<section class="section" style="padding-top:1rem">
  <div class="wrap">
    <span class="kicker center">The Detail</span>
    <h2 style="text-align:center;font-size:var(--text-2xl);margin-top:.4rem">{{HL_HEADING}}</h2>
    <ul class="th-ideas">
{{HIGHLIGHTS}}
    </ul>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap">
    <span class="kicker center">Good To Know</span>
    <h2 style="text-align:center;font-size:var(--text-2xl);margin-top:.4rem">{{NAME}} FAQs</h2>
    <div class="th-faq-wrap">
{{FAQ}}
    </div>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap"><div class="cta-band reveal">
    <span class="kicker center">Ready When You Are</span>
    <h2>Let's plan your <em>celebration.</em></h2>
    <p>Tell us the date, the age and your budget &mdash; our Singapore concierge will craft a tailored plan and handle every detail.</p>
    <div class="cta-actions"><a class="btn btn-primary btn-lg" href="plan.html">Plan Your Party</a><a class="btn btn-ghost btn-lg" href="contact.html">Contact Us</a></div>
  </div></div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap">
    <span class="kicker center">Explore More</span>
    <h2 style="text-align:center;font-size:var(--text-2xl);margin-top:.4rem">You might also like</h2>
    <div class="theme-grid" style="margin-top:2rem">
{{RELATED}}
    </div>
  </div>
</section>
</main>
{{FOOTER}}
</body>
</html>
'@

$clusterSlugs = @()

foreach ($c in $collections) {
    $entries = Load $c.file
    foreach ($t in $entries) {
        $clusterSlugs += $t.slug
        $nameEsc = Esc $t.name
        $titleNameEsc = Esc $t.titleName

        $hlHtml = ($t.highlights | ForEach-Object { "      <li>$_</li>" }) -join "`n"
        $faqHtml = ($t.faqs | ForEach-Object {
            "      <details class=""faq""><summary>$($_.q)</summary><div>$($_.a)</div></details>"
        }) -join "`n"
        $relHtml = ($t.related | ForEach-Object {
            $r = $lookup[$_]
            if ($null -ne $r) {
                "      <a class=""theme-card reveal"" href=""$($r.slug).html""><img src=""$($r.image)"" alt=""$(Esc $r.titleName)""><div class=""tc-label""><strong>$(Esc $r.name)</strong><span>Learn more</span></div></a>"
            }
        }) -join "`n"

        # --- Structured data ---
        $service = [ordered]@{
            '@context' = 'https://schema.org'; '@type' = 'Service'
            serviceType = $t.titleName
            name = "$($t.titleName) in Singapore"
            description = $t.metaDescription
            areaServed = [ordered]@{ '@type' = 'Country'; name = 'Singapore' }
            provider = [ordered]@{ '@type' = 'LocalBusiness'; name = 'OurKampung'; url = "$origin/" }
        }
        $faqPage = [ordered]@{
            '@context' = 'https://schema.org'; '@type' = 'FAQPage'
            mainEntity = @($t.faqs | ForEach-Object {
                [ordered]@{ '@type' = 'Question'; name = $_.q
                    acceptedAnswer = [ordered]@{ '@type' = 'Answer'; text = $_.a } }
            })
        }
        $crumbItems = @([ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Home'; item = "$origin/" })
        $pos = 2
        if ($c.crumbUrl) {
            $crumbItems += [ordered]@{ '@type' = 'ListItem'; position = $pos; name = $c.crumbName; item = "$origin/$($c.crumbUrl)" }
            $pos++
        }
        $crumbItems += [ordered]@{ '@type' = 'ListItem'; position = $pos; name = $t.name; item = "$origin/$($t.slug).html" }
        $crumb = [ordered]@{ '@context' = 'https://schema.org'; '@type' = 'BreadcrumbList'; itemListElement = $crumbItems }

        $jsonld = (@($service, $faqPage, $crumb) | ForEach-Object {
            "<script type=""application/ld+json"">`n" + ($_ | ConvertTo-Json -Depth 12) + "`n</script>"
        }) -join "`n"

        $title = "$titleNameEsc in Singapore &mdash; OurKampung"

        $html = $template.
            Replace('{{GA}}',        $ga).
            Replace('{{HEADER}}',    $header).
            Replace('{{FOOTER}}',    $footer).
            Replace('{{CSS}}',       $scopedCss).
            Replace('{{JSONLD}}',    $jsonld).
            Replace('{{ORIGIN}}',    $origin).
            Replace('{{TITLE}}',     $title).
            Replace('{{DESC}}',      $t.metaDescription).
            Replace('{{SLUG}}',      $t.slug).
            Replace('{{IMG}}',       $t.image).
            Replace('{{KICKER}}',    $t.kicker).
            Replace('{{H1}}',        $t.h1).
            Replace('{{HL_HEADING}}',$c.heading).
            Replace('{{NAME}}',      $nameEsc).
            Replace('{{INTRO}}',     $t.intro).
            Replace('{{HIGHLIGHTS}}',$hlHtml).
            Replace('{{FAQ}}',       $faqHtml).
            Replace('{{RELATED}}',   $relHtml)

        $outPath = Join-Path $repo "$($t.slug).html"
        [System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  generated  $($t.slug).html"
    }
}

# ---- Rebuild the COMPLETE sitemap (core + themes + all clusters) ----
$themeSlugs = (Load 'themes.json' | ForEach-Object { $_.slug })
$core = @(
    @{ loc = "$origin/";                 freq = 'weekly';  pri = '1.0' },
    @{ loc = "$origin/birthdays.html";   freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/events.html";      freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/themes.html";      freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/services.html";    freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/how-it-works.html";freq = 'monthly'; pri = '0.7' },
    @{ loc = "$origin/plan.html";        freq = 'monthly'; pri = '0.9' },
    @{ loc = "$origin/contact.html";     freq = 'yearly';  pri = '0.6' }
)
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($u in $core) {
    [void]$sb.AppendLine("  <url><loc>$($u.loc)</loc><lastmod>$lastmod</lastmod><changefreq>$($u.freq)</changefreq><priority>$($u.pri)</priority></url>")
}
foreach ($s in ($themeSlugs + $clusterSlugs)) {
    [void]$sb.AppendLine("  <url><loc>$origin/$s.html</loc><lastmod>$lastmod</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>")
}
[void]$sb.AppendLine('</urlset>')
[System.IO.File]::WriteAllText((Join-Path $repo 'sitemap.xml'), $sb.ToString().TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Done. $($clusterSlugs.Count) landing pages + complete sitemap ($(($themeSlugs.Count + $clusterSlugs.Count + $core.Count)) URLs)." -ForegroundColor Green
