<#
  Generate-Articles.ps1
  --------------------------------------------------------------
  Generates the Guides/blog cluster: one article page per entry in
  data/articles.json, plus the blog.html index, plus the COMPLETE
  sitemap (core + blog + themes + all clusters + articles).

  Run this LAST so the sitemap reflects every page.
      powershell -ExecutionPolicy Bypass -File scripts/Generate-Articles.ps1
#>

$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$origin  = 'https://ourkampung.com'
$lastmod = '2026-08-03'
$months  = @{ '01'='Jan'; '02'='Feb'; '03'='Mar'; '04'='Apr'; '05'='May'; '06'='Jun'; '07'='Jul'; '08'='Aug'; '09'='Sep'; '10'='Oct'; '11'='Nov'; '12'='Dec' }

function Esc([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return '' }
    return ($s -replace '&(?!amp;|lt;|gt;|quot;|#\d+;|#x[0-9a-fA-F]+;)', '&amp;')
}
function Load([string]$name) {
    $p = Join-Path $repo "data/$name"
    if (Test-Path $p) { return @(Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}
function PrettyDate([string]$iso) {
    $parts = $iso.Split('-')
    if ($parts.Count -eq 3) { return "$([int]$parts[2]) $($months[$parts[1]]) $($parts[0])" }
    return $iso
}

# Global lookup for related cards (landing pages live in these clusters).
$lookup = @{}
foreach ($f in 'themes.json','milestones.json','services.json','locations.json') {
    foreach ($x in (Load $f)) { if ($x -and $x.slug) { $lookup[$x.slug] = $x } }
}
$articles = Load 'articles.json'

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
<div class="mobile-menu"><a href="birthdays.html">Kids Birthdays</a><a href="services.html">Services</a><a href="themes.html">Themes</a><a href="events.html">Other Events</a><a href="how-it-works.html">How It Works</a><a href="blog.html">Guides</a><a href="contact.html">Contact</a><a class="btn btn-primary" href="plan.html">Start Planning</a></div>
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

$headCommon = @'
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
{{GA}}
<title>{{TITLE}}</title>
<meta name="description" content="{{DESC}}">
<link rel="canonical" href="{{CANON}}">
<meta name="theme-color" content="#7E8A6E">
<meta property="og:site_name" content="OurKampung">
<meta property="og:locale" content="en_SG">
<meta property="og:type" content="{{OGTYPE}}">
<meta property="og:url" content="{{CANON}}">
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
'@

$articleCss = @'
<style>
  .article-meta{text-align:center;color:var(--faint);font-size:var(--text-sm);margin-top:.85rem;letter-spacing:.02em}
  .article-figure{margin:2.25rem auto 0;max-width:900px;border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow-md)}
  .article-body{max-width:720px;margin:2.5rem auto 0}
  .article-body h2{font-size:var(--text-xl);margin:2.2rem 0 .6rem}
  .article-body p{margin-bottom:1rem;color:var(--muted);font-size:var(--text-lg)}
  .article-body ul{margin:0 0 1.2rem 1.3rem;color:var(--muted);font-size:var(--text-lg)}
  .article-body li{margin-bottom:.45rem}
  .article-body a{color:var(--terra);text-decoration:underline;text-underline-offset:2px}
  .article-body strong{color:var(--ink)}
  .th-faq-wrap{max-width:720px;margin:2.5rem auto 0}
  .faq{background:var(--surface);border:1px solid var(--border-soft);border-radius:var(--radius);margin-bottom:.75rem;overflow:hidden}
  .faq summary{cursor:pointer;padding:1.05rem 1.35rem;font-family:var(--font-display);font-size:var(--text-lg);list-style:none;display:flex;justify-content:space-between;gap:1rem}
  .faq summary::-webkit-details-marker{display:none}
  .faq summary::after{content:"+";color:var(--gold)}
  .faq[open] summary::after{content:"\2013"}
  .faq div{padding:0 1.35rem 1.2rem;color:var(--muted)}
  .post-grid{display:grid;gap:1.5rem;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));margin-top:2.5rem}
  .post-card{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--border-soft);border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow-sm);transition:transform .3s var(--ease),box-shadow .3s var(--ease)}
  .post-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-md)}
  .post-card img{aspect-ratio:16/10;object-fit:cover;width:100%}
  .post-card .pc-body{padding:1.4rem 1.5rem 1.6rem;display:flex;flex-direction:column;gap:.55rem;flex:1}
  .post-card h3{font-size:var(--text-lg);line-height:1.15}
  .post-card p{color:var(--muted);font-size:var(--text-sm);flex:1}
  .post-card .pc-meta{color:var(--faint);font-size:var(--text-xs)}
</style>
'@

# ---------------- Article pages ----------------
$articleSlugs = @()
foreach ($a in $articles) {
    $articleSlugs += $a.slug
    $canon = "$origin/$($a.slug).html"
    $titleEsc = Esc $a.title
    $dateNice = PrettyDate $a.datePublished

    $bodyHtml = ($a.sections | ForEach-Object { "      <h2>$($_.h2)</h2>`n      $($_.html)" }) -join "`n"

    $faqBlock = ''
    if ($a.faqs) {
        $faqItems = ($a.faqs | ForEach-Object {
            "      <details class=""faq""><summary>$($_.q)</summary><div>$($_.a)</div></details>"
        }) -join "`n"
        $faqBlock = @"
<section class="section" style="padding-top:0">
  <div class="wrap">
    <span class="kicker center">Good To Know</span>
    <h2 style="text-align:center;font-size:var(--text-2xl);margin-top:.4rem">Common questions</h2>
    <div class="th-faq-wrap">
$faqItems
    </div>
  </div>
</section>
"@
    }

    $relHtml = ($a.related | ForEach-Object {
        $r = $lookup[$_]
        if ($null -ne $r) {
            "      <a class=""theme-card reveal"" href=""$($r.slug).html""><img src=""$($r.image)"" alt=""$(Esc $r.titleName)""><div class=""tc-label""><strong>$(Esc $r.name)</strong><span>Learn more</span></div></a>"
        }
    }) -join "`n"

    # Structured data: BlogPosting + (FAQPage) + BreadcrumbList
    $posting = [ordered]@{
        '@context' = 'https://schema.org'; '@type' = 'BlogPosting'
        headline = $a.title
        description = $a.metaDescription
        image = "$origin/$($a.image)"
        datePublished = $a.datePublished
        dateModified = $a.datePublished
        mainEntityOfPage = $canon
        author = [ordered]@{ '@type' = 'Organization'; name = 'OurKampung'; url = "$origin/" }
        publisher = [ordered]@{ '@type' = 'Organization'; name = 'OurKampung'; url = "$origin/" }
    }
    $ld = @($posting)
    if ($a.faqs) {
        $ld += [ordered]@{
            '@context' = 'https://schema.org'; '@type' = 'FAQPage'
            mainEntity = @($a.faqs | ForEach-Object {
                [ordered]@{ '@type' = 'Question'; name = $_.q; acceptedAnswer = [ordered]@{ '@type' = 'Answer'; text = $_.a } }
            })
        }
    }
    $ld += [ordered]@{
        '@context' = 'https://schema.org'; '@type' = 'BreadcrumbList'
        itemListElement = @(
            [ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Home'; item = "$origin/" },
            [ordered]@{ '@type' = 'ListItem'; position = 2; name = 'Guides'; item = "$origin/blog.html" },
            [ordered]@{ '@type' = 'ListItem'; position = 3; name = $a.title; item = $canon }
        )
    }
    $jsonld = ($ld | ForEach-Object { "<script type=""application/ld+json"">`n" + ($_ | ConvertTo-Json -Depth 12) + "`n</script>" }) -join "`n"

    $head = $headCommon.
        Replace('{{GA}}', $ga).Replace('{{TITLE}}', "$titleEsc &mdash; OurKampung").
        Replace('{{DESC}}', $a.metaDescription).Replace('{{CANON}}', $canon).
        Replace('{{OGTYPE}}', 'article').Replace('{{ORIGIN}}', $origin).Replace('{{IMG}}', $a.image)

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
$head
$jsonld
$articleCss
</head>
<body>
$header
<main>
<section class="page-hero">
  <div class="wrap wrap-narrow">
    <span class="kicker center">Guide</span>
    <h1 style="text-align:center">$titleEsc</h1>
    <p style="text-align:center">$($a.dek)</p>
    <p class="article-meta">$dateNice &middot; $($a.readMins) min read</p>
    <figure class="article-figure"><img src="$($a.image)" alt="$titleEsc"></figure>
  </div>
</section>

<section class="section" style="padding-top:1.5rem">
  <div class="wrap">
    <div class="article-body">
$bodyHtml
    </div>
  </div>
</section>

$faqBlock

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
    <span class="kicker center">Related</span>
    <h2 style="text-align:center;font-size:var(--text-2xl);margin-top:.4rem">You might also like</h2>
    <div class="theme-grid" style="margin-top:2rem">
$relHtml
    </div>
  </div>
</section>
</main>
$footer
</body>
</html>
"@

    [System.IO.File]::WriteAllText((Join-Path $repo "$($a.slug).html"), $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  generated  $($a.slug).html"
}

# ---------------- blog.html index ----------------
$cards = ($articles | ForEach-Object {
    "      <a class=""post-card reveal"" href=""$($_.slug).html""><img src=""$($_.image)"" alt=""$(Esc $_.title)""><div class=""pc-body""><span class=""pc-meta"">$(PrettyDate $_.datePublished) &middot; $($_.readMins) min read</span><h3>$(Esc $_.title)</h3><p>$($_.excerpt)</p><span style=""color:var(--terra);font-size:var(--text-sm);font-weight:600"">Read guide &rarr;</span></div></a>"
}) -join "`n"

$blogHead = $headCommon.
    Replace('{{GA}}', $ga).Replace('{{TITLE}}', 'Party Planning Guides &mdash; OurKampung Singapore').
    Replace('{{DESC}}', 'Practical guides to planning a kids'' birthday party in Singapore — costs, checklists, theme ideas and venue advice from the OurKampung concierge.').
    Replace('{{CANON}}', "$origin/blog.html").
    Replace('{{OGTYPE}}', 'website').Replace('{{ORIGIN}}', $origin).Replace('{{IMG}}', 'assets/hero.png')

$blog = @"
<!DOCTYPE html>
<html lang="en">
<head>
$blogHead
$articleCss
</head>
<body>
$header
<main>
<section class="page-hero">
  <div class="wrap">
    <span class="kicker center">Guides &amp; Inspiration</span>
    <h1>Party planning, <em>made simple.</em></h1>
    <p>Honest, practical guides for Singapore parents — costs, checklists, theme ideas and where to host. Everything we've learned, shared freely.</p>
  </div>
</section>

<section class="section" style="padding-top:1rem">
  <div class="wrap">
    <div class="post-grid">
$cards
    </div>
  </div>
</section>
</main>
$footer
</body>
</html>
"@
[System.IO.File]::WriteAllText((Join-Path $repo 'blog.html'), $blog, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  generated  blog.html"

# ---------------- Complete sitemap ----------------
$themeSlugs = (Load 'themes.json' | ForEach-Object { $_.slug })
$clusterSlugs = @()
foreach ($f in 'milestones.json','services.json','locations.json') { $clusterSlugs += (Load $f | ForEach-Object { $_.slug }) }

$core = @(
    @{ loc = "$origin/";                 freq = 'weekly';  pri = '1.0' },
    @{ loc = "$origin/birthdays.html";   freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/events.html";      freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/themes.html";      freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/services.html";    freq = 'monthly'; pri = '0.8' },
    @{ loc = "$origin/how-it-works.html";freq = 'monthly'; pri = '0.7' },
    @{ loc = "$origin/plan.html";        freq = 'monthly'; pri = '0.9' },
    @{ loc = "$origin/blog.html";        freq = 'weekly';  pri = '0.7' },
    @{ loc = "$origin/contact.html";     freq = 'yearly';  pri = '0.6' }
)
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($u in $core) {
    [void]$sb.AppendLine("  <url><loc>$($u.loc)</loc><lastmod>$lastmod</lastmod><changefreq>$($u.freq)</changefreq><priority>$($u.pri)</priority></url>")
}
foreach ($s in ($themeSlugs + $clusterSlugs + $articleSlugs)) {
    [void]$sb.AppendLine("  <url><loc>$origin/$s.html</loc><lastmod>$lastmod</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>")
}
[void]$sb.AppendLine('</urlset>')
[System.IO.File]::WriteAllText((Join-Path $repo 'sitemap.xml'), $sb.ToString().TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Done. $($articleSlugs.Count) articles + blog.html + complete sitemap ($(($core.Count + $themeSlugs.Count + $clusterSlugs.Count + $articleSlugs.Count)) URLs)." -ForegroundColor Green
