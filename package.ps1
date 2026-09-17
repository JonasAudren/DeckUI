<#
    package.ps1 - build the CurseForge upload zip for DeckUI.

    Writes dist\DeckUI-<version>.zip with the four addon folders at the TOP
    LEVEL of the archive. A wrapping folder would install every addon one
    level too deep, so the archive layout is printed at the end for a look.

    Repository files that are not part of the addon (CLAUDE.md, the git
    metadata, this script) are left out, as is the developer clutter that
    ships inside libs\oUF (.github, utils, .luacheckrc, .pkgmeta) and the
    unused LibStub/CallbackHandler copies that other libraries bundle.

    The archive is written through System.IO.Compression with explicit entry
    names: Compress-Archive on Windows PowerShell 5.1 separates them with
    backslashes, which the zip format does not allow and which trips up
    extractors outside Windows.

    Usage:  powershell -ExecutionPolicy Bypass -File package.ps1
#>

$ErrorActionPreference = "Stop"

$root   = $PSScriptRoot
$addons = @("DeckUI", "DeckUI_Orbs", "DeckUI_Cross", "DeckUI_Spec")
$extras = @("README.txt", "LICENSE.txt", "THIRD-PARTY.txt")   # shipped inside the DeckUI folder
$dist   = Join-Path $root "dist"

# Developer files that live in the libraries but must not ship.
$dropDirs  = @(".github", "utils")
$dropFiles = @(".editorconfig", ".gitattributes", ".luacheckrc", ".pkgmeta",
               "Thumbs.db", ".DS_Store")

# Libraries that bundle their own copies of LibStub and CallbackHandler.
# DeckUI_Cross.toc loads exactly one copy of each, so these never run and
# only bloat the archive. Listed by path, so nothing goes by accident.
$dropPaths = @(
    "DeckUI_Cross/libs/LibStub/tests",
    "DeckUI_Cross/libs/CallbackHandler-1.0/LibStub",
    "DeckUI_Cross/libs/LibActionButton-1.0/LibStub",
    "DeckUI_Cross/libs/LibActionButton-1.0/CallbackHandler-1.0"
)

function Get-TocField($path, $field) {
    foreach ($line in Get-Content $path) {
        if ($line -match "^##\s+$field\s*:\s*(.+?)\s*$") { return $matches[1] }
    }
    return $null
}

# --- the four .toc files must agree on version and interface ----------
$versions   = @()
$interfaces = @()
foreach ($a in $addons) {
    $toc = Join-Path $root "$a\$a.toc"
    if (-not (Test-Path $toc)) { throw "missing $toc" }
    $v = Get-TocField $toc "Version"
    $i = Get-TocField $toc "Interface"
    if (-not $v) { throw "no ## Version in $toc" }
    if (-not $i) { throw "no ## Interface in $toc" }
    $versions   += $v
    $interfaces += $i
    Write-Host ("  {0,-14} version {1}  interface {2}" -f $a, $v, $i)
}

$uniqueVersions   = @($versions   | Sort-Object -Unique)
$uniqueInterfaces = @($interfaces | Sort-Object -Unique)
if ($uniqueVersions.Count -ne 1) {
    throw "the .toc files disagree on ## Version: " + ($uniqueVersions -join ", ")
}
if ($uniqueInterfaces.Count -ne 1) {
    throw "the .toc files disagree on ## Interface: " + ($uniqueInterfaces -join ", ")
}
$version = $uniqueVersions[0]

# A missing project id is fine before the CurseForge project exists, but it
# is easy to forget, so say so rather than silently shipping without it.
$hubToc = Join-Path $root "DeckUI\DeckUI.toc"
if (-not (Get-TocField $hubToc "X-Curse-Project-ID")) {
    Write-Host "  note: X-Curse-Project-ID is not set yet" -ForegroundColor Yellow
}

# --- stage a clean copy ------------------------------------------------
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("deckui-pkg-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $stage | Out-Null
try {
    foreach ($a in $addons) {
        Copy-Item (Join-Path $root $a) -Destination $stage -Recurse
    }

    foreach ($e in $extras) {
        $src = Join-Path $root $e
        if (Test-Path $src) { Copy-Item $src -Destination (Join-Path $stage "DeckUI") }
    }

    foreach ($d in $dropDirs) {
        Get-ChildItem $stage -Recurse -Directory -Filter $d -Force |
            ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    }
    foreach ($f in $dropFiles) {
        Get-ChildItem $stage -Recurse -File -Filter $f -Force |
            ForEach-Object { Remove-Item $_.FullName -Force }
    }
    foreach ($rel in $dropPaths) {
        $full = Join-Path $stage $rel
        if (Test-Path $full) {
            Remove-Item $full -Recurse -Force
        } else {
            Write-Host "  note: nothing at $rel, did a library change?" -ForegroundColor Yellow
        }
    }

    # --- zip it, entry names with forward slashes ---------------------
    if (-not (Test-Path $dist)) { New-Item -ItemType Directory $dist | Out-Null }
    $zip = Join-Path $dist "DeckUI-$version.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $stream  = [System.IO.File]::Open($zip, [System.IO.FileMode]::Create)
    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in (Get-ChildItem $stage -Recurse -File | Sort-Object FullName)) {
            $name  = $file.FullName.Substring($stage.Length + 1).Replace("\", "/")
            $entry = $archive.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
            $out   = $entry.Open()
            try {
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $out.Write($bytes, 0, $bytes.Length)
            } finally {
                $out.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
        $stream.Dispose()
    }

    # --- show what came out -------------------------------------------
    Write-Host ""
    Write-Host ("  {0}  ({1:N0} KB)" -f $zip, ((Get-Item $zip).Length / 1KB))
    Write-Host ""

    $check = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $names = $check.Entries | ForEach-Object { $_.FullName }
        $bad   = @($names | Where-Object { $_ -like "*\*" })
        if ($bad.Count -gt 0) { throw "entry names contain backslashes: " + $bad[0] }

        Write-Host "  top level of the archive (must be the four addon folders):"
        $groups = $names | Group-Object { ($_ -split "/")[0] } | Sort-Object Name
        foreach ($g in $groups) {
            $mark = "  "
            if ($addons -notcontains $g.Name) { $mark = "!!" }
            Write-Host ("  {0} {1,-14} {2,4} files" -f $mark, $g.Name, $g.Count)
        }
        $unexpected = @($groups | Where-Object { $addons -notcontains $_.Name })
        if ($unexpected.Count -gt 0) {
            throw "unexpected entries at the top level: " + (($unexpected | ForEach-Object { $_.Name }) -join ", ")
        }
    } finally {
        $check.Dispose()
    }

    Write-Host ""
    Write-Host "  ready to upload" -ForegroundColor Green
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}
