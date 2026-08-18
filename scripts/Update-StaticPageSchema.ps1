<#
  Update-StaticPageSchema.ps1

  Injects structured data into the HAND-MAINTAINED pages (index + the section
  hubs), which no other generator owns. Everything else gets its schema from
  Generate-LandingPages / Generate-ThemePages / Generate-Articles.

  data/business.json is the single source of truth for the business entity, so
  these pages stay in sync with the generated ones instead of drifting.

  Title / description / image are read back out of each page's existing <head>,
  so this script never invents copy - edit the page, re-run, done.

  Idempotent: strips any previously injected block before writing a fresh one.
#>

$ErrorActionPreference = 'Stop'
$repo   = Split-Path $PSScriptRoot -Parent
$origin = 'https://ourkampung.com'

$business = Get-Content (Join-Path $repo 'data/business.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$bizRef   = [ordered]@{ '@id' = "$origin/#business" }
$siteRef  = [ordered]@{ '@id' = "$origin/#website" }
$website  = [ordered]@{
    '@type'    = 'WebSite'
    '@id'      = "$origin/#website"
    url        = "$origin/"
    name       = 'OurKampung'
    publisher  = $bizRef
    inLanguage = 'en-SG'
}

# list = data file whose entries this hub genuinely enumerates ($null = no ItemList)
$pages = @(
    @{ file = 'index.html';        type = 'WebPage';        crumb = $null;             list = $null }
    @{ file = 'services.html';     type = 'CollectionPage'; crumb = 'Services';        list = 'services.json' }
    @{ file = 'themes.html';       type = 'CollectionPage'; crumb = 'Themes';          list = 'themes.json' }
    @{ file = 'events.html';       type = 'CollectionPage'; crumb = 'Other Events';    list = 'milestones.json' }
    @{ file = 'birthdays.html';    type = 'CollectionPage'; crumb = 'Kids Birthdays';  list = $null }
    @{ file = 'how-it-works.html'; type = 'WebPage';        crumb = 'How It Works';    list = $null }
    @{ file = 'plan.html';         type = 'WebPage';        crumb = 'Plan Your Party'; list = $null }
    @{ file = 'contact.html';      type = 'ContactPage';    crumb = 'Contact';         list = $null }
)

function Load([string]$name) {
    $p = Join-Path $repo "data/$name"
    if (Test-Path $p) { return @(Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}
function Decode([string]$s) {
    if (-not $s) { return $s }
    $s = $s.Replace('&mdash;','—').Replace('&ndash;','–')
    $s = $s.Replace('&rsquo;',"’").Replace('&lsquo;',"‘")
    $s = $s.Replace('&quot;','"').Replace('&#39;',"'").Replace('&amp;','&')
    return $s.Trim()
}
function Grab([string]$html, [string]$pattern) {
    $m = [regex]::Match($html, $pattern, 'Singleline')
    if ($m.Success) { return Decode $m.Groups[1].Value }
    return $null
}

$count = 0
foreach ($p in $pages) {
    $path = Join-Path $repo $p.file
    if (-not (Test-Path $path)) { Write-Host "  (skipped $($p.file): not found)" -ForegroundColor Yellow; continue }
    $html = [System.IO.File]::ReadAllText($path)

    $canon = if ($p.file -eq 'index.html') { "$origin/" } else { "$origin/$($p.file)" }
    $name  = Grab $html '<title>(.*?)</title>'
    $desc  = Grab $html '<meta name="description" content="(.*?)">'
    $img   = Grab $html '<meta property="og:image" content="(.*?)">'

    $page = [ordered]@{
        '@type'    = $p.type
        '@id'      = "$canon#webpage"
        url        = $canon
        name       = $name
        isPartOf   = $siteRef
        about      = $bizRef
        inLanguage = 'en-SG'
    }
    if ($desc) { $page['description'] = $desc }
    if ($img)  { $page['primaryImageOfPage'] = [ordered]@{ '@type' = 'ImageObject'; url = $img } }

    $graph = @($business, $website)

    if ($p.list) {
        $entries = Load $p.list
        $i = 0
        $items = @($entries | ForEach-Object {
            $i++
            $label = if ($_.titleName) { $_.titleName } else { $_.name }
            [ordered]@{ '@type' = 'ListItem'; position = $i; url = "$origin/$($_.slug).html"; name = $label }
        })
        $page['mainEntity'] = [ordered]@{
            '@type'         = 'ItemList'
            '@id'           = "$canon#list"
            numberOfItems   = $items.Count
            itemListElement = $items
        }
    }

    if ($p.crumb) {
        $page['breadcrumb'] = [ordered]@{ '@id' = "$canon#breadcrumb" }
        $graph += $page
        $graph += [ordered]@{
            '@type' = 'BreadcrumbList'
            '@id'   = "$canon#breadcrumb"
            itemListElement = @(
                [ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Home';     item = "$origin/" },
                [ordered]@{ '@type' = 'ListItem'; position = 2; name = $p.crumb;   item = $canon }
            )
        }
    } else {
        $graph += $page
    }

    $json = [ordered]@{ '@context' = 'https://schema.org'; '@graph' = $graph } | ConvertTo-Json -Depth 12
    $block = "<!--SCHEMA:START-->`n<script type=""application/ld+json"">`n$json`n</script>`n<!--SCHEMA:END-->"

    # Idempotent: drop a previous injected block, then any legacy stray JSON-LD.
    $html = [regex]::Replace($html, '(?s)\s*<!--SCHEMA:START-->.*?<!--SCHEMA:END-->', '')
    $html = [regex]::Replace($html, '(?s)\s*<script type="application/ld\+json">.*?</script>', '')
    $html = $html.Replace('<html lang="en">', '<html lang="en-SG">')
    $html = $html.Replace('</head>', "$block`n</head>")

    [System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  schema     $($p.file)"
    $count++
}

Write-Host ""
Write-Host "Done. structured data injected into $count static pages." -ForegroundColor Green
