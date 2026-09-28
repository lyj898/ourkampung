<#
  Build-Site.ps1 -- builds the entire OurKampung site from data/ and content/.

  Every page is rendered through ONE shell template, so the GA4 tag, the Search
  Console verification tag, the header and the footer each exist in exactly one
  place. Output is plain static HTML for GitHub Pages.

    data/site.json          site-wide settings, GA4 ID, verification token
    data/organization.json  the OurKampung Organization node (schema.org)
    data/brands.json        the four sister businesses and their deep links
    data/sources.json       official sources guides cite (HDB, NEA, ...)
    data/hubs.json          the five life-event hubs
    data/guides.json        guide metadata, FAQs, get-help links
    data/pages.json         home, about, contact, tools, 404
    content/hubs/*.html     hub intro copy
    content/guides/*.html   guide body copy
    content/pages/*.html    static page copy

  Content files may use tokens, all resolved and validated at build time -- an
  unknown token fails the build, so a broken internal link cannot ship:
    {{guide:<slug>}}  {{hub:<slug>}}  {{page:<id>}}  {{src:<key>}}
    {{brand:<brandId>/<linkKey>}}

  <!-- OWNER-INPUT: ... --> comments mark where first-hand material from the
  businesses would strengthen a page. They are stripped from the output and
  collected into OWNER-INPUT.md.

  Run:  powershell -ExecutionPolicy Bypass -File scripts/Build-Site.ps1
#>

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$inv  = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:written = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- helpers ---
function Load([string]$name) {
    # Function output unrolls the array ConvertFrom-Json returns. A bare
    # @(Get-Content ... | ConvertFrom-Json) assignment would nest it one level.
    $p = Join-Path $repo "data/$name"
    if (Test-Path $p) { return @(Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}
function LoadObj([string]$name) {
    return (Get-Content (Join-Path $repo "data/$name") -Raw -Encoding UTF8 | ConvertFrom-Json)
}
function ReadText([string]$rel) {
    $p = Join-Path $repo $rel
    if (-not (Test-Path $p)) { throw "Missing content file: $rel" }
    return [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
}
function Esc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }
function Abs([string]$path) { return $site.origin + $path }
function Pretty([string]$d) { return [datetime]::ParseExact($d, 'yyyy-MM-dd', $inv).ToString('d MMMM yyyy', $inv) }
function Get-Modified($x) {
    if ($x.PSObject.Properties['dateModified'] -and $x.dateModified) { return $x.dateModified }
    return $x.datePublished
}
function Short-Hash([string]$rel) {
    # Hash the text with line endings normalised. git's autocrlf rewrites
    # LF/CRLF on checkout, and hashing raw bytes made every page's ?v= change
    # (a diff on all pages, and a needless re-download) when nothing had.
    $text = [IO.File]::ReadAllText((Join-Path $repo $rel), [Text.Encoding]::UTF8).Replace("`r`n", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $sha = [Security.Cryptography.SHA1]::Create()
    return ((($sha.ComputeHash($bytes)) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 8)
}
function Out-Page([string]$urlPath, [string]$html) {
    if ($urlPath -eq '/') { $rel = 'index.html' }
    elseif ($urlPath.EndsWith('/')) { $rel = $urlPath.Trim('/') + '/index.html' }
    else { $rel = $urlPath.TrimStart('/') }
    $full = Join-Path $repo $rel
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($full, $html, $utf8)
    $script:written.Add($rel.Replace('/', '\'))
}

# ------------------------------------------------------------------ data ---
$site    = LoadObj 'site.json'
$org     = LoadObj 'organization.json'
$sources = LoadObj 'sources.json'
$brands  = Load 'brands.json'
$hubs    = Load 'hubs.json'
$guides  = Load 'guides.json'
$pages   = Load 'pages.json'

# Continuity guard. These two values tie the site to its existing GA4 property
# and its Search Console verification. Changing either would silently start a
# new analytics history or un-verify Search Console. Change them only on
# purpose, and update the expected values here in the same commit.
$expectedGA  = 'G-8XGK5F86ZX'
$expectedGSV = 'HjvZuJxCuygLjDF7qlHp54oWb6OJQmloOGrro1TWqGs'
if ($site.ga4MeasurementId -ne $expectedGA)        { throw "GA4 measurement ID is '$($site.ga4MeasurementId)', expected $expectedGA." }
if ($site.googleSiteVerification -ne $expectedGSV) { throw "Search Console verification token changed from $expectedGSV." }

$brandById = @{};   foreach ($b in $brands) { $brandById[$b.id] = $b }
$hubBySlug = @{};   foreach ($h in $hubs)   { $hubBySlug[$h.slug] = $h }
$guideBySlug = @{}; foreach ($g in $guides) { $guideBySlug[$g.slug] = $g }
$pageById = @{};    foreach ($p in $pages)  { $pageById[$p.id] = $p }

foreach ($g in $guides) {
    if (-not $hubBySlug.ContainsKey($g.hub)) { throw "Guide '$($g.slug)' points at unknown hub '$($g.hub)'." }
    if (@($hubBySlug[$g.hub].guides) -notcontains $g.slug) { throw "Guide '$($g.slug)' is not listed in hub '$($g.hub)'." }
}
foreach ($h in $hubs) {
    foreach ($s in @($h.guides)) { if (-not $guideBySlug.ContainsKey($s)) { throw "Hub '$($h.slug)' lists unknown guide '$s'." } }
}

function GuideUrl($g) { return "/$($g.hub)/$($g.slug)/" }

function Brand-Link([string]$brandId, [string]$key) {
    if (-not $brandById.ContainsKey($brandId)) { return $null }
    $b = $brandById[$brandId]
    foreach ($bag in @('links', 'articles')) {
        $coll = $b.PSObject.Properties[$bag]
        if ($coll) {
            $item = $coll.Value.PSObject.Properties[$key]
            if ($item) { return $item.Value }
        }
    }
    return $null
}

# ---------------------------------------------------------------- tokens ---
$script:tokenErrors = New-Object System.Collections.Generic.List[string]
$script:tokenWhere = ''
$tokenEval = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    $kind = $m.Groups[1].Value
    $key  = $m.Groups[2].Value
    $out  = $null
    switch ($kind) {
        'guide' { if ($guideBySlug.ContainsKey($key)) { $out = GuideUrl $guideBySlug[$key] } }
        'hub'   { if ($hubBySlug.ContainsKey($key))   { $out = "/$key/" } }
        'page'  { if ($pageById.ContainsKey($key))    { $out = $pageById[$key].path } }
        'src'   { $sp = $sources.PSObject.Properties[$key]; if ($sp) { $out = $sp.Value.url } }
        'brand' {
            $bits = $key.Split('/')
            if ($bits.Count -eq 2) { $l = Brand-Link $bits[0] $bits[1]; if ($l) { $out = $l.url } }
        }
    }
    if ($null -eq $out) {
        $script:tokenErrors.Add("$($script:tokenWhere): {{${kind}:$key}}")
        return $m.Value
    }
    return $out
}
function Resolve-Tokens([string]$html, [string]$where) {
    $script:tokenWhere = $where
    $html = $html.Replace('{{FORM_ENDPOINT}}', $site.formEndpoint)
    return [regex]::Replace($html, '\{\{(guide|hub|page|src|brand):([a-z0-9\-/]+)\}\}', $tokenEval)
}

# --------------------------------------------------------- owner input ---
$ownerNotes = New-Object System.Collections.Generic.List[object]
function Take-OwnerNotes([string]$html, [string]$label, [string]$url) {
    foreach ($m in [regex]::Matches($html, '<!--\s*OWNER-INPUT:\s*(.*?)\s*-->', 'Singleline')) {
        $ownerNotes.Add([pscustomobject]@{ page = $label; url = $url; note = ($m.Groups[1].Value -replace '\s+', ' ') })
    }
    return [regex]::Replace($html, '[ \t]*<!--\s*OWNER-INPUT:.*?-->[ \t]*\r?\n?', '', 'Singleline')
}

# ------------------------------------------------------------- headings ---
function Slugify([string]$s) {
    $s = [System.Net.WebUtility]::HtmlDecode($s).ToLowerInvariant()
    $s = $s -replace "[\u2019']", ''
    $s = $s -replace '[^a-z0-9]+', '-'
    return $s.Trim('-')
}
$headEval = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    $inner = $m.Groups[1].Value
    $plain = ($inner -replace '<[^>]+>', '').Trim()
    $id = Slugify $plain
    $base = $id; $n = 2
    while ($script:tocIds.Contains($id)) { $id = "$base-$n"; $n++ }
    [void]$script:tocIds.Add($id)
    $script:toc.Add([pscustomobject]@{ id = $id; text = $plain })
    return "<h2 id=""$id"">$inner</h2>"
}
function Add-HeadingIds([string]$html) {
    $script:toc = New-Object System.Collections.Generic.List[object]
    $script:tocIds = New-Object System.Collections.Generic.HashSet[string]
    return [regex]::Replace($html, '<h2>(.*?)</h2>', $headEval, [System.Text.RegularExpressions.RegexOptions]::Singleline)
}
function Count-Words([string]$html) {
    $t = [System.Net.WebUtility]::HtmlDecode(($html -replace '<[^>]+>', ' '))
    return ([regex]::Matches($t, "[A-Za-z0-9\u2019']+")).Count
}

# ------------------------------------------------------------ fragments ---
$logoSvg = '<svg class="logo-mark" viewBox="0 0 40 40" fill="none" aria-hidden="true"><path d="M20 4c2.2 5.6 5.1 8.5 10.7 10.7C25.1 16.9 22.2 19.8 20 25.4 17.8 19.8 14.9 16.9 9.3 14.7 14.9 12.5 17.8 9.6 20 4z" fill="currentColor"/><circle cx="30.5" cy="28" r="3" fill="#B0663F"/><circle cx="10.5" cy="30" r="2.2" fill="#B79A5B"/></svg>'

$svgOpen = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
$icons = @{
    truck   = $svgOpen + '<path d="M2.5 6.5h11v9.5h-11z"/><path d="M13.5 10h4.2l3.3 3.4V16h-7.5z"/><circle cx="6.5" cy="17.6" r="1.9"/><circle cx="17" cy="17.6" r="1.9"/></svg>'
    key     = $svgOpen + '<circle cx="8" cy="15" r="4.2"/><path d="M11 12l9.5-9.5"/><path d="M16.5 6.5l3 3"/><path d="M14 9l2 2"/></svg>'
    door    = $svgOpen + '<path d="M5 21V4.2c0-.7.5-1.2 1.2-1.2H15v18"/><path d="M15 3l4 1.6V21"/><path d="M3 21h18"/><path d="M12 12h.01"/></svg>'
    bin     = $svgOpen + '<path d="M4 7h16"/><path d="M9.5 7V4.5h5V7"/><path d="M6 7l1 13h10l1-13"/><path d="M10 11v5.5M14 11v5.5"/></svg>'
    wrench  = $svgOpen + '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3.5 17.5 6.5 20.5l5.8-5.8a4 4 0 0 0 5.4-5.4l-2.4 2.4-2.3-.6-.6-2.3z"/></svg>'
    planner = $svgOpen + '<rect x="3" y="4.5" width="18" height="16.5" rx="2"/><path d="M3 9.5h18M8 2.5v4M16 2.5v4"/><path d="M8.5 15l2.2 2.2 4.8-4.8"/></svg>'
}

$gaSnippet = @"
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=$($site.ga4MeasurementId)"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', '$($site.ga4MeasurementId)');
</script>
"@
$verifyTag = "<meta name=""google-site-verification"" content=""$($site.googleSiteVerification)"">"

$cssV = Short-Hash 'css/style.css'
$jsV  = Short-Hash 'js/main.js'

function Build-Header([string]$active) {
    $items = foreach ($h in $hubs) {
        $cur = if ($h.slug -eq $active) { ' aria-current="page"' } else { '' }
        "<li><a href=""/$($h.slug)/""$cur>$(Esc $h.navLabel)</a></li>"
    }
    $mob = foreach ($h in $hubs) { "<a href=""/$($h.slug)/"">$(Esc $h.name)</a>" }
    return @"
<a class="skip" href="#main">Skip to content</a>
<header class="header">
  <div class="wrap nav">
    <a href="/" class="brand" aria-label="OurKampung home">$logoSvg<span class="logo-txt">Our<em>Kampung</em></span></a>
    <nav aria-label="Primary"><ul class="nav-links">
      $($items -join "`n      ")
    </ul></nav>
    <div class="nav-cta"><a class="btn btn-ghost btn-sm" href="/tools/moving-planner/">$($icons.planner)Moving planner</a></div>
    <button class="burger" type="button" aria-label="Menu" aria-expanded="false" aria-controls="mobile-menu"><span></span><span></span><span></span></button>
  </div>
</header>
<div class="mobile-menu" id="mobile-menu">$($mob -join '')<a href="/tools/moving-planner/">Moving planner</a><a href="/about/">About OurKampung</a></div>
"@
}

$hubLinks = ($hubs | ForEach-Object { "<li><a href=""/$($_.slug)/"">$(Esc $_.name)</a></li>" }) -join ''
$year = (Get-Date).Year
$footer = @"
<footer class="footer"><div class="wrap">
  <div class="footer-grid">
    <div class="footer-about">
      <a href="/" class="brand">$logoSvg<span class="logo-txt">Our<em>Kampung</em></span></a>
      <p>$(Esc $site.tagline).</p>
    </div>
    <div><h2 class="fh">Guides</h2><ul>$hubLinks</ul></div>
    <div><h2 class="fh">OurKampung</h2><ul><li><a href="/about/">About &amp; how we work</a></li><li><a href="/tools/moving-planner/">Moving planner</a></li><li><a href="/contact/">Contact the editors</a></li></ul></div>
  </div>
  <p class="footer-disclose">OurKampung is written by the team behind JunkToClear, HomeToClean, HomeToMoved and SkillsToFix. We link to them only where a guide covers something they do. <a href="/about/">How we work</a>.</p>
  <div class="footer-bottom"><p>&copy; $year OurKampung &middot; ourkampung.com</p></div>
</div></footer>
"@

$shell = @'
<!DOCTYPE html>
<html lang="{{LANG}}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script>document.documentElement.className+=' js'</script>
{{VERIFY}}{{GA}}
<title>{{TITLE}}</title>
<meta name="description" content="{{DESC}}">
<link rel="canonical" href="{{CANON}}">
{{ROBOTS}}<meta name="theme-color" content="#7E8A6E">
<meta property="og:site_name" content="OurKampung">
<meta property="og:locale" content="{{OGLOCALE}}">
<meta property="og:type" content="{{OGTYPE}}">
<meta property="og:url" content="{{CANON}}">
<meta property="og:title" content="{{TITLE}}">
<meta property="og:description" content="{{DESC}}">
<meta property="og:image" content="{{OGIMAGE}}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
{{ARTICLEMETA}}<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{{TITLE}}">
<meta name="twitter:description" content="{{DESC}}">
<meta name="twitter:image" content="{{OGIMAGE}}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400..600;1,9..144,400..500&display=swap" rel="stylesheet">
<link href="https://api.fontshare.com/v2/css?f[]=satoshi@300,400,500,700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/css/style.css?v={{CSSV}}">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath d='M16 3l3.6 8.2L28 12l-6 6 1.5 8.5L16 22.5 8.5 26.5 10 18l-6-6 8.4-.8z' fill='%237E8A6E'/%3E%3C/svg%3E">
{{JSONLD}}
</head>
<body class="{{BODYCLASS}}">
{{HEADER}}
<main id="main">
{{MAIN}}
</main>
{{FOOTER}}
<script src="/js/main.js?v={{JSV}}" defer></script>
{{SCRIPTS}}</body>
</html>
'@

function Render-Page($opt) {
    $h = $shell
    $h = $h.Replace('{{LANG}}', $site.lang).Replace('{{OGLOCALE}}', $site.ogLocale)
    $h = $h.Replace('{{VERIFY}}', $(if ($opt.verify) { $verifyTag + "`n" } else { '' }))
    $h = $h.Replace('{{GA}}', $gaSnippet)
    $h = $h.Replace('{{TITLE}}', (Esc $opt.title)).Replace('{{DESC}}', (Esc $opt.description))
    $h = $h.Replace('{{CANON}}', (Abs $opt.path))
    $h = $h.Replace('{{ROBOTS}}', $(if ($opt.noindex) { "<meta name=""robots"" content=""noindex, follow"">`n" } else { '' }))
    $h = $h.Replace('{{OGTYPE}}', $(if ($opt.ogType) { $opt.ogType } else { 'website' }))
    $h = $h.Replace('{{OGIMAGE}}', (Abs '/assets/og-image.png'))
    $h = $h.Replace('{{ARTICLEMETA}}', $(if ($opt.articleMeta) { $opt.articleMeta } else { '' }))
    $h = $h.Replace('{{CSSV}}', $cssV).Replace('{{JSV}}', $jsV)
    $h = $h.Replace('{{BODYCLASS}}', $opt.bodyClass)
    $h = $h.Replace('{{JSONLD}}', $(if ($opt.jsonld) { $opt.jsonld } else { '' }))
    $scripts = ''
    foreach ($s in @($opt.scripts)) { if ($s) { $scripts += "<script src=""/$s`?v=$(Short-Hash $s)"" defer></script>`n" } }
    $h = $h.Replace('{{SCRIPTS}}', $scripts)
    $h = $h.Replace('{{HEADER}}', (Build-Header $opt.activeHub)).Replace('{{FOOTER}}', $footer)
    return $h.Replace('{{MAIN}}', $opt.main)
}

# ---------------------------------------------------------------- schema ---
$orgRef  = [ordered]@{ '@id' = "$($site.origin)/#organization" }
$siteRef = [ordered]@{ '@id' = "$($site.origin)/#website" }
$websiteNode = [ordered]@{
    '@type' = 'WebSite'; '@id' = "$($site.origin)/#website"; url = "$($site.origin)/"
    name = $site.name; description = $site.description; publisher = $orgRef; inLanguage = $site.lang
}
function JsonLd($graph) {
    $obj = [ordered]@{ '@context' = 'https://schema.org'; '@graph' = @($graph) }
    return "<script type=""application/ld+json"">`n" + ($obj | ConvertTo-Json -Depth 30) + "`n</script>"
}
function Crumb-Items($trail) {
    # $trail: array of @{ name; url }, Home is prepended here
    return @(@{ name = 'Home'; url = '/' }) + @($trail)
}
function Crumbs-Node([string]$canon, $items) {
    $i = 0
    $els = @(foreach ($it in $items) { $i++; [ordered]@{ '@type' = 'ListItem'; position = $i; name = $it.name; item = (Abs $it.url) } })
    return [ordered]@{ '@type' = 'BreadcrumbList'; '@id' = "$canon#breadcrumb"; itemListElement = $els }
}
function Crumbs-Html($items) {
    $parts = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $it = $items[$i]
        if ($i -eq $items.Count - 1) { $parts += "<span aria-current=""page"">$(Esc $it.name)</span>" }
        else { $parts += "<a href=""$($it.url)"">$(Esc $it.name)</a>" }
    }
    return '<nav class="crumbs" aria-label="Breadcrumb">' + ($parts -join '<span class="sep" aria-hidden="true">/</span>') + '</nav>'
}
function Page-Node([string]$type, [string]$canon, [string]$name, [string]$desc, [bool]$hasCrumbs) {
    $n = [ordered]@{
        '@type' = $type; '@id' = "$canon#webpage"; url = $canon; name = $name; description = $desc
        isPartOf = $siteRef; about = $orgRef; inLanguage = $site.lang
        primaryImageOfPage = [ordered]@{ '@type' = 'ImageObject'; url = (Abs '/assets/og-image.png') }
    }
    if ($hasCrumbs) { $n['breadcrumb'] = [ordered]@{ '@id' = "$canon#breadcrumb" } }
    return $n
}

# ---------------------------------------------------------- components ---
$script:readMins = @{}
function Guide-Card($g, [bool]$showHub) {
    $hub = $hubBySlug[$g.hub]
    $hubLine = if ($showHub) { "<span class=""gc-hub"">$(Esc $hub.name)</span>" } else { '' }
    return "<a class=""guide-card reveal"" href=""$(GuideUrl $g)"">$hubLine<h3>$(Esc $g.title)</h3><p>$(Esc $g.description)</p><span class=""gc-meta"">$($script:readMins[$g.slug]) min read</span></a>"
}
function Hub-Card($h) {
    $n = @($h.guides).Count
    $label = if ($n -eq 1) { '1 guide' } else { "$n guides" }
    return "<a class=""hub-card reveal"" href=""/$($h.slug)/""><span class=""hub-icon"">$($icons[$h.icon])</span><h3>$(Esc $h.name)</h3><p>$(Esc $h.blurb)</p><span class=""hub-count"">$label</span></a>"
}
function GetHelp-Html($items) {
    $items = @($items | Where-Object { $_ })
    if ($items.Count -eq 0) { return '' }
    $lis = foreach ($it in $items) {
        $l = Brand-Link $it.brand $it.link
        if (-not $l) { throw "Unknown brand link '$($it.brand)/$($it.link)'." }
        $b = $brandById[$it.brand]
        "<li><a href=""$($l.url)""><strong>$(Esc $l.label)</strong><span>$(Esc $b.name) &middot; $(Esc $b.does)</span></a></li>"
    }
    return @"
<aside class="gethelp" aria-labelledby="gethelp-h">
  <h2 id="gethelp-h">Need a hand with this?</h2>
  <p class="disclose">These businesses are run by the same team that writes OurKampung. <a href="/about/">Here&rsquo;s how that works</a>.</p>
  <ul>$($lis -join '')</ul>
</aside>
"@
}
function Further-Html($items) {
    $items = @($items | Where-Object { $_ })
    if ($items.Count -eq 0) { return '' }
    $lis = foreach ($it in $items) {
        $l = Brand-Link $it.brand $it.article
        if (-not $l) { throw "Unknown further-reading link '$($it.brand)/$($it.article)'." }
        "<li><a href=""$($l.url)"">$(Esc $l.label)</a> <span>on the $(Esc $brandById[$it.brand].name) blog</span></li>"
    }
    return @"
<section class="further" aria-labelledby="further-h">
  <h2 id="further-h">Already covered by our sister sites</h2>
  <p class="disclose">Rather than repeat them here, these guides live on a site run by the same team.</p>
  <ul>$($lis -join '')</ul>
</section>
"@
}
function Faq-Html($faqs) {
    $d = foreach ($f in @($faqs)) { "<details class=""faq""><summary>$(Esc $f.q)</summary><div><p>$(Esc $f.a)</p></div></details>" }
    return "<section class=""faqs"" aria-labelledby=""faqs""><h2 id=""faqs"">Common questions</h2>$($d -join '')</section>"
}
function Faq-Entities($faqs) {
    return @(foreach ($f in @($faqs)) {
        [ordered]@{ '@type' = 'Question'; name = $f.q; acceptedAnswer = [ordered]@{ '@type' = 'Answer'; text = $f.a } }
    })
}

$sitemap = New-Object System.Collections.Generic.List[object]
function Add-Sitemap([string]$path, [string]$lastmod) { $sitemap.Add([pscustomobject]@{ loc = (Abs $path); lastmod = $lastmod }) }

# ------------------------------------------- pass 1: process guide bodies ---
$processed = @{}
foreach ($g in $guides) {
    $url = GuideUrl $g
    $body = ReadText "content/guides/$($g.slug).html"
    $body = Take-OwnerNotes $body "Guide: $($g.title)" $url
    $body = Resolve-Tokens $body "content/guides/$($g.slug).html"
    $body = Add-HeadingIds $body
    $words = Count-Words $body
    $script:readMins[$g.slug] = [int][math]::Max(1, [math]::Ceiling($words / 220))
    # .ToArray(), not @(): PS 5.1 throws "Argument types do not match" on
    # @($genericList) inside a [pscustomobject] literal.
    $processed[$g.slug] = [pscustomobject]@{ body = $body; toc = $script:toc.ToArray(); words = $words }
}

# ------------------------------------------------------ pass 2: guides ---
foreach ($g in $guides) {
    $hub = $hubBySlug[$g.hub]
    $path = GuideUrl $g
    $canon = Abs $path
    $pr = $processed[$g.slug]
    $mod = Get-Modified $g
    $hasFaqs = ($g.PSObject.Properties['faqs'] -and @($g.faqs).Count -gt 0)

    $crumbs = Crumb-Items @(@{ name = $hub.name; url = "/$($hub.slug)/" }, @{ name = $g.title; url = $path })

    $tocHtml = ''
    if ($pr.toc.Count -ge 3) {
        $lis = foreach ($t in $pr.toc) { "<li><a href=""#$($t.id)"">$($t.text)</a></li>" }
        if ($hasFaqs) { $lis += '<li><a href="#faqs">Common questions</a></li>' }
        $tocHtml = "<nav class=""toc"" aria-labelledby=""toc-h""><p class=""toc-h"" id=""toc-h"">In this guide</p><ol>$($lis -join '')</ol></nav>"
    }
    $dateLabel = if ($mod -ne $g.datePublished) { 'Updated' } else { 'Published' }
    $relatedHtml = ''
    $rel = @($g.related | Where-Object { $_ })
    if ($rel.Count -gt 0) {
        $cards = foreach ($s in $rel) {
            if (-not $guideBySlug.ContainsKey($s)) { throw "Guide '$($g.slug)' relates to unknown guide '$s'." }
            Guide-Card $guideBySlug[$s] $true
        }
        $relatedHtml = "<section class=""related"" aria-labelledby=""related-h""><h2 id=""related-h"">Keep reading</h2><div class=""card-grid two"">$($cards -join '')</div></section>"
    }
    $faqHtml = if ($hasFaqs) { Faq-Html $g.faqs } else { '' }

    $main = @"
<article class="guide">
  <header class="guide-head"><div class="wrap-narrow">
    $(Crumbs-Html $crumbs)
    <h1>$(Esc $g.title)</h1>
    <p class="dek">$(Esc $g.dek)</p>
    <p class="meta"><span>$dateLabel <time datetime="$mod">$(Pretty $mod)</time></span><span>$($script:readMins[$g.slug]) min read</span><span>By the OurKampung team</span></p>
  </div></header>
  <div class="wrap-narrow guide-body">
    $tocHtml
    <div class="prose">
$($pr.body.Trim())
    </div>
    $faqHtml
    $(GetHelp-Html $g.getHelp)
    $relatedHtml
  </div>
</article>
"@

    $pageType = if ($hasFaqs) { @('WebPage', 'FAQPage') } else { 'WebPage' }
    $pageNode = Page-Node 'WebPage' $canon $g.title $g.description $true
    $pageNode['@type'] = $pageType
    if ($hasFaqs) { $pageNode['mainEntity'] = Faq-Entities $g.faqs }
    $article = [ordered]@{
        '@type' = 'Article'; '@id' = "$canon#article"; headline = $g.title; description = $g.description
        image = [ordered]@{ '@type' = 'ImageObject'; url = (Abs '/assets/og-image.png'); width = 1200; height = 630 }
        datePublished = $g.datePublished; dateModified = $mod
        author = $orgRef; publisher = $orgRef
        mainEntityOfPage = [ordered]@{ '@id' = "$canon#webpage" }; isPartOf = $siteRef
        articleSection = $hub.name; wordCount = $pr.words; inLanguage = $site.lang
    }
    $jsonld = JsonLd @($org, $websiteNode, $pageNode, $article, (Crumbs-Node $canon $crumbs))
    $articleMeta = "<meta property=""article:published_time"" content=""$($g.datePublished)"">`n<meta property=""article:modified_time"" content=""$mod"">`n"

    Out-Page $path (Render-Page ([pscustomobject]@{
        path = $path; title = "$($g.title) | OurKampung"; description = $g.description; ogType = 'article'
        articleMeta = $articleMeta; jsonld = $jsonld; main = $main; bodyClass = 'page-guide'; activeHub = $hub.slug
        verify = $false; noindex = $false; scripts = @()
    }))
    Add-Sitemap $path $mod
}

# -------------------------------------------------------------- hubs ---
foreach ($h in $hubs) {
    $path = "/$($h.slug)/"
    $canon = Abs $path
    $intro = ReadText "content/hubs/$($h.slug).html"
    $intro = Take-OwnerNotes $intro "Hub: $($h.name)" $path
    $intro = Resolve-Tokens $intro "content/hubs/$($h.slug).html"
    $hubGuides = @($h.guides | ForEach-Object { $guideBySlug[$_] })
    $cards = ($hubGuides | ForEach-Object { Guide-Card $_ $false }) -join ''
    $lastmod = ($hubGuides | ForEach-Object { Get-Modified $_ } | Sort-Object -Descending | Select-Object -First 1)
    $crumbs = Crumb-Items @(@{ name = $h.name; url = $path })

    $toolHtml = ''
    foreach ($tid in @($h.tools | Where-Object { $_ })) {
        $t = $pageById[$tid]
        if (-not $t) { throw "Hub '$($h.slug)' lists unknown tool '$tid'." }
        $toolHtml += "<a class=""tool-card reveal"" href=""$($t.path)""><span class=""hub-icon"">$($icons.planner)</span><span><strong>$(Esc $t.cardTitle)</strong><span>$(Esc $t.cardText)</span></span></a>"
    }
    if ($toolHtml) { $toolHtml = "<section class=""section section-tight""><div class=""wrap-narrow"">$toolHtml</div></section>" }

    $main = @"
<section class="page-hero"><div class="wrap-narrow">
  $(Crumbs-Html $crumbs)
  <span class="hub-icon lg">$($icons[$h.icon])</span>
  <h1>$($h.h1)</h1>
  <p class="lede">$(Esc $h.lede)</p>
</div></section>
<section class="section section-tight"><div class="wrap-narrow prose hub-intro">
$($intro.Trim())
</div></section>
<section class="section section-tight"><div class="wrap">
  <h2 class="sec-title">Guides in this section</h2>
  <div class="card-grid">$cards</div>
</div></section>
$toolHtml
<section class="section section-tight"><div class="wrap-narrow">
  $(Further-Html $h.furtherReading)
  $(GetHelp-Html $h.getHelp)
</div></section>
"@
    $i = 0
    $listEls = @(foreach ($gg in $hubGuides) { $i++; [ordered]@{ '@type' = 'ListItem'; position = $i; url = (Abs (GuideUrl $gg)); name = $gg.title } })
    $pageNode = Page-Node 'CollectionPage' $canon $h.title $h.description $true
    $pageNode['mainEntity'] = [ordered]@{ '@type' = 'ItemList'; '@id' = "$canon#list"; numberOfItems = $listEls.Count; itemListElement = $listEls }
    $jsonld = JsonLd @($org, $websiteNode, $pageNode, (Crumbs-Node $canon $crumbs))

    Out-Page $path (Render-Page ([pscustomobject]@{
        path = $path; title = "$($h.title) | OurKampung"; description = $h.description; ogType = 'website'
        jsonld = $jsonld; main = $main; bodyClass = 'page-hub'; activeHub = $h.slug; verify = $false; noindex = $false; scripts = @()
    }))
    Add-Sitemap $path $lastmod
}

# ------------------------------------------------------- static pages ---
$allGuideCards = ($guides | ForEach-Object { Guide-Card $_ $true }) -join ''
$hubCards = ($hubs | ForEach-Object { Hub-Card $_ }) -join ''
$siteLastmod = ($guides | ForEach-Object { Get-Modified $_ } | Sort-Object -Descending | Select-Object -First 1)

foreach ($p in $pages) {
    $path = $p.path
    $canon = Abs $path
    $html = ReadText $p.file
    $html = Take-OwnerNotes $html "Page: $($p.title)" $path
    $html = Resolve-Tokens $html $p.file
    $html = $html.Replace('<!--HUBS-->', $hubCards).Replace('<!--ALLGUIDES-->', $allGuideCards)
    if ($p.PSObject.Properties['featured']) {
        $feat = ($p.featured | ForEach-Object {
            if (-not $guideBySlug.ContainsKey($_)) { throw "Page '$($p.id)' features unknown guide '$_'." }
            Guide-Card $guideBySlug[$_] $true
        }) -join ''
        $html = $html.Replace('<!--FEATURED-->', $feat)
    }
    $isHome = ($p.id -eq 'home')
    $crumbs = $null
    if (-not $isHome -and $p.PSObject.Properties['crumb']) {
        $trail = @()
        foreach ($c in @($p.crumbParents | Where-Object { $_ })) { $trail += @{ name = $c.name; url = $c.url } }
        $trail += @{ name = $p.crumb; url = $path }
        $crumbs = Crumb-Items $trail
        $html = $html.Replace('<!--CRUMBS-->', (Crumbs-Html $crumbs))
    }

    $jsonld = ''
    if (-not ($p.PSObject.Properties['schema'] -and $p.schema -eq $false)) {
        $graph = @($org, $websiteNode, (Page-Node $p.schemaType $canon $p.title $p.description ($null -ne $crumbs)))
        if ($p.PSObject.Properties['app'] -and $p.app) {
            $graph += [ordered]@{
                '@type' = 'WebApplication'; '@id' = "$canon#app"; name = $p.cardTitle; url = $canon
                description = $p.description; applicationCategory = 'LifestyleApplication'
                operatingSystem = 'Any'; isAccessibleForFree = $true; publisher = $orgRef; inLanguage = $site.lang
            }
        }
        if ($crumbs) { $graph += Crumbs-Node $canon $crumbs }
        $jsonld = JsonLd $graph
    }
    $active = if ($p.PSObject.Properties['activeHub']) { $p.activeHub } else { '' }
    $noindex = ($p.PSObject.Properties['noindex'] -and $p.noindex)

    Out-Page $path (Render-Page ([pscustomobject]@{
        path = $path; title = $p.title; description = $p.description; ogType = 'website'
        jsonld = $jsonld; main = $html; bodyClass = "page-$($p.id)"; activeHub = $active
        verify = $isHome; noindex = $noindex; scripts = @($p.scripts)
    }))
    if (-not ($p.PSObject.Properties['sitemap'] -and $p.sitemap -eq $false)) {
        $lm = if ($isHome) { $siteLastmod } elseif ($p.PSObject.Properties['updated']) { $p.updated } else { $siteLastmod }
        Add-Sitemap $path $lm
    }
}

if ($script:tokenErrors.Count -gt 0) {
    throw ("Unresolved tokens (nothing written to sitemap):`n  " + ($script:tokenErrors -join "`n  "))
}

# ----------------------------------------------------------- sitemap ---
$ordered = $sitemap | Sort-Object { if ($_.loc -eq (Abs '/')) { 0 } else { 1 } }, loc
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($e in $ordered) { [void]$sb.AppendLine("  <url><loc>$($e.loc)</loc><lastmod>$($e.lastmod)</lastmod></url>") }
[void]$sb.Append('</urlset>')
[IO.File]::WriteAllText((Join-Path $repo 'sitemap.xml'), $sb.ToString() + "`n", $utf8)

# ------------------------------------------------------ owner input doc ---
$od = New-Object System.Text.StringBuilder
[void]$od.AppendLine('# Where first-hand material would strengthen the guides')
[void]$od.AppendLine('')
[void]$od.AppendLine('Generated by `scripts/Build-Site.ps1` from the `<!-- OWNER-INPUT: ... -->` markers in `content/`. Do not edit by hand.')
[void]$od.AppendLine('Every page reads fine without these, but real numbers and photos from the businesses are what separate this site from generic advice.')
[void]$od.AppendLine('')
[void]$od.AppendLine('| Page | URL | What would help |')
[void]$od.AppendLine('|---|---|---|')
foreach ($n in $ownerNotes) { [void]$od.AppendLine("| $($n.page) | ``$($n.url)`` | $($n.note) |") }
[IO.File]::WriteAllText((Join-Path $repo 'OWNER-INPUT.md'), $od.ToString(), $utf8)

# ------------------------------------------------------ post-build checks ---
$fail = @()
foreach ($rel in $script:written) {
    $txt = [IO.File]::ReadAllText((Join-Path $repo $rel), [Text.Encoding]::UTF8)
    if ($txt -notmatch [regex]::Escape("gtag/js?id=$expectedGA")) { $fail += "$rel is missing the GA4 tag" }
    if ($txt -match '\{\{[A-Za-z]') { $fail += "$rel still contains an unreplaced {{token}}" }
}
$homeHtml = [IO.File]::ReadAllText((Join-Path $repo 'index.html'), [Text.Encoding]::UTF8)
if ($homeHtml -notmatch [regex]::Escape($expectedGSV)) { $fail += 'index.html is missing the Search Console verification tag' }
if ($fail.Count) { throw ("Post-build checks failed:`n  " + ($fail -join "`n  ")) }

$skip = '\\(\.git|\.claude|node_modules|backend|content)(\\|$)'
$orphans = @(Get-ChildItem $repo -Recurse -Filter *.html -File | ForEach-Object {
    $rel = $_.FullName.Substring($repo.Length + 1)
    if (('\' + $rel) -notmatch $skip -and -not $script:written.Contains($rel)) { $rel }
})

Write-Host ''
Write-Host "Built $($script:written.Count) pages ($($guides.Count) guides, $($hubs.Count) hubs, $($pages.Count) static) + sitemap ($($sitemap.Count) URLs)." -ForegroundColor Green
Write-Host "GA4 tag on every page: yes. Verification tag on index.html: yes."
Write-Host "OWNER-INPUT.md: $($ownerNotes.Count) notes."
if ($orphans.Count) {
    Write-Host "Stale .html files not produced by this build ($($orphans.Count)) -- delete them or they stay live:" -ForegroundColor Yellow
    $orphans | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
