<#
  Generate-Redirects.ps1

  GitHub Pages serves static files only, so there is no server-side 301. This
  writes a minimal stub for every entry in data/redirects.json that combines a
  canonical link with an instant meta refresh - the standard static-host way to
  consolidate a retired URL into its replacement.

  Stubs are deliberately NOT added to sitemap.xml: they exist so that a retired
  URL already known to Google resolves to its replacement instead of 404ing,
  not to be crawled as content in their own right.

  Run after the content generators. Does not touch sitemap.xml.
#>

$ErrorActionPreference = 'Stop'
$repo   = Split-Path $PSScriptRoot -Parent
$origin = 'https://ourkampung.com'

function Load([string]$name) {
    $p = Join-Path $repo "data/$name"
    if (Test-Path $p) { return @(Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}

$redirects = Load 'redirects.json'
if (-not $redirects) {
    Write-Host "No redirects defined in data/redirects.json." -ForegroundColor Yellow
    return
}

$count = 0
foreach ($r in $redirects) {
    if (-not $r.from -or -not $r.to) { continue }
    $target = "$($r.to).html"
    $html = @"
<!DOCTYPE html>
<html lang="en-SG">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Page moved &mdash; OurKampung</title>
<link rel="canonical" href="$origin/$target">
<meta http-equiv="refresh" content="0; url=$target">
<meta name="description" content="This page has moved. See our kids' party venue guide for Singapore.">
</head>
<body>
<p>This page has moved. If you are not redirected automatically, <a href="$target">continue to the venue guide</a>.</p>
</body>
</html>
"@
    [System.IO.File]::WriteAllText((Join-Path $repo "$($r.from).html"), $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  redirect   $($r.from).html -> $target"
    $count++
}

Write-Host ""
Write-Host "Done. $count redirect stubs written (not added to sitemap.xml)." -ForegroundColor Green
