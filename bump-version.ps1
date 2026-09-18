<#
    bump-version.ps1 - raise ## Version in the four .toc files at once.

    package.ps1 -Version stamps the release version into the staged copies
    only, so the repository keeps whatever its .toc files say. That is right
    for the build, but it means the repository and CurseForge drift apart
    unless the version is raised here first. Four files, one line each, and
    the build only prints a yellow note when they disagree - easy to forget,
    hence this script.

    ## Interface can be raised in the same go, for the day a game patch
    lands: package.ps1 aborts when the four files disagree on it.

    The files are written through .NET without a BOM and keep their line
    endings, for the reason package.ps1 explains: Set-Content puts a BOM in
    front of ## Interface on Windows PowerShell, which WoW dislikes.

    Usage:  powershell -ExecutionPolicy Bypass -File bump-version.ps1 1.0.1
            pwsh ./bump-version.ps1 1.0.1 -Interface 120200
            pwsh ./bump-version.ps1 1.0.1 -DryRun
#>

param(
    # The new version, e.g. 1.0.1. A leading v is stripped, so a tag name works.
    [Parameter(Mandatory, Position = 0)] [string]$Version,

    # New ## Interface for a game patch, e.g. 120200. Left out it stays put.
    [string]$Interface,

    # Show what would change and write nothing.
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root   = $PSScriptRoot
$addons = @("DeckUI", "DeckUI_Orbs", "DeckUI_Cross", "DeckUI_Spec")

$newVersion = $Version -replace "^v", ""

# Deliberately loose: WoW does not care about the shape, but a typo like
# "1..1" or a pasted quote should not end up in a shipped .toc.
if ($newVersion -notmatch "^\d+(\.\d+){1,3}([-.][0-9A-Za-z][0-9A-Za-z.-]*)?$") {
    throw "'$newVersion' does not look like a version (expected e.g. 1.0.1 or 1.1.0-beta)"
}
if ($Interface -and $Interface -notmatch "^\d{5,6}$") {
    throw "'$Interface' does not look like an interface number (expected e.g. 120100)"
}

function Get-TocField($path, $field) {
    foreach ($line in Get-Content $path) {
        if ($line -match "^##\s+$field\s*:\s*(.+?)\s*$") { return $matches[1] }
    }
    return $null
}

# Replace the one header line, and insist that it was there: a silent no-op
# would ship the old version under a new tag.
#
# The character class instead of a dot: in .NET a dot matches every character
# but the newline itself, so on a CRLF working copy it also eats the carriage
# return and leaves that one line ending bare, mixing both styles in the file.
function Set-TocField([string]$text, [string]$field, [string]$value, [string]$where) {
    $pattern = "(?m)^##\s+$field\s*:[^\r\n]*"
    $hits    = [regex]::Matches($text, $pattern).Count
    if ($hits -ne 1) { throw "$where has $hits '## $field' lines, expected exactly one" }
    return [regex]::Replace($text, $pattern, "## ${field}: $value")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$changed   = 0

foreach ($a in $addons) {
    $toc = Join-Path $root "$a/$a.toc"
    if (-not (Test-Path $toc)) { throw "missing $toc" }

    $oldVersion   = Get-TocField $toc "Version"
    $oldInterface = Get-TocField $toc "Interface"
    if (-not $oldVersion)   { throw "no ## Version in $toc" }
    if (-not $oldInterface) { throw "no ## Interface in $toc" }

    $text = Get-Content $toc -Raw
    $new  = Set-TocField $text "Version" $newVersion "$a.toc"
    if ($Interface) { $new = Set-TocField $new "Interface" $Interface "$a.toc" }

    $note = "version {0} -> {1}" -f $oldVersion, $newVersion
    if ($Interface) { $note += ", interface {0} -> {1}" -f $oldInterface, $Interface }

    if ($new -eq $text) {
        Write-Host ("  {0,-14} already at {1}" -f $a, $newVersion)
        continue
    }

    if (-not $DryRun) { [System.IO.File]::WriteAllText($toc, $new, $utf8NoBom) }
    Write-Host ("  {0,-14} {1}" -f $a, $note)
    $changed++
}

# The release falls back to the commit subjects when CHANGELOG.md has no
# section for this version. That is a working release with a dull changelog,
# so it is worth a nudge here rather than a failure later.
$log = Join-Path $root "CHANGELOG.md"
if (Test-Path $log) {
    $headings = @(Get-Content $log | Where-Object { $_.StartsWith("## ") } |
                  ForEach-Object { $_.Substring(3).Trim().TrimStart("v").Split(" ")[0] })
    if ($headings -notcontains $newVersion) {
        Write-Host ""
        Write-Host ("  CHANGELOG.md has no '## {0}' section yet - write one before tagging," -f $newVersion) -ForegroundColor Yellow
        Write-Host "  or the release ships the commit subjects instead." -ForegroundColor Yellow
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host ("  dry run, nothing written ({0} file(s) would change)" -f $changed) -ForegroundColor Yellow
    return
}
if ($changed -eq 0) {
    Write-Host "  nothing to do" -ForegroundColor Yellow
    return
}

Write-Host ("  {0} .toc file(s) updated" -f $changed) -ForegroundColor Green

Write-Host ""
Write-Host "  next, to release this version:"
Write-Host ("    git add {0}" -f (($addons | ForEach-Object { "$_/$_.toc" }) -join " "))
Write-Host ("    git commit -m ""Raise the version to {0}""" -f $newVersion)
Write-Host ("    git push && git tag v{0} && git push origin v{0}" -f $newVersion)
Write-Host ""
Write-Host "  the tag starts the Release workflow, which uploads to CurseForge as beta."
