<#
    changelog.ps1 - work out the changelog text a release ships with.

    CurseForge shows this on the file's page and in the app, so it is the one
    place where a user reads what changed. Two sources, in this order:

    1. The section for this version in CHANGELOG.md, written by hand in the
       words a player understands. This one should normally win. A
       pre-release falls back to the version it leads up to, so 1.0.1-beta
       uses the "## 1.0.1" section rather than needing one of its own.
    2. Failing that, the commit subjects since the previous tag. They are
       whole sentences in this repository, so they read acceptably - but they
       also carry build and release plumbing nobody outside cares about.

    Falling back rather than failing is deliberate: a forgotten section
    should not stop a release, it should only make it duller. The run log
    says which source was used.

    The previous tag comes from git describe, so it is the previous tag in
    this commit's history rather than whatever sorts highest. Needs the full
    history: a shallow clone has no tags, so the script says so instead of
    writing an empty list.

    Usage:  pwsh ./changelog.ps1 1.0.1
            pwsh ./changelog.ps1 1.0.1 -FromCommits
            pwsh ./changelog.ps1 1.0.1 -Since v1.0.0
            pwsh ./changelog.ps1 1.0.1 -OutFile release-notes.md
#>

param(
    # Version this changelog is for, e.g. 1.0.1. A leading v is stripped.
    [Parameter(Mandatory, Position = 0)] [string]$Version,

    # The handwritten changelog. Default: CHANGELOG.md next to this script.
    [string]$File,

    # Ignore CHANGELOG.md and use the commits, for comparing the two.
    [switch]$FromCommits,

    # Start of the commit range, a tag like v1.0.0. Found with git describe
    # when left out.
    [string]$Since,

    # owner/repo for the compare link. Read from the origin remote when left
    # out; the workflow passes github.repository.
    [string]$Repo,

    # Write here instead of to standard output. Notes always go to the host,
    # so the file holds nothing but the changelog.
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

# Windows PowerShell turns a native command's stderr into an error record
# while $ErrorActionPreference is Stop, so git's "No names found" from a
# repository without tags would abort the script instead of just meaning
# "there is no earlier tag". These calls are judged by their exit code
# instead, with the preference relaxed for the duration.
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$GitArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @GitArgs 2>$null
        $ok     = ($LASTEXITCODE -eq 0)
        # Consume the exit code. The caller judges the call by .Ok, while a
        # non-zero $LASTEXITCODE left lying around ends the GitHub Actions
        # step with a failure - and "there is no earlier tag" is a normal
        # answer here, not a broken build.
        $global:LASTEXITCODE = 0
        return [pscustomobject]@{ Ok = $ok; Output = $output }
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Pull "## <version>" out of CHANGELOG.md and return everything up to the
# next "## " heading. Headings may read "## 1.0.1", "## v1.0.1" or
# "## 1.0.1 - 2026-09-20"; only the first word counts. Plain string work
# rather than a regex, because a version is full of dots.
function Get-HandwrittenSection([string]$path, [string]$version) {
    if (-not (Test-Path $path)) { return $null }

    $section    = New-Object System.Collections.Generic.List[string]
    $collecting = $false
    foreach ($line in Get-Content $path) {
        if ($line.StartsWith("## ")) {
            if ($collecting) { break }
            $heading = $line.Substring(3).Trim().TrimStart("v")
            if ($heading.Split(" ")[0] -eq $version) { $collecting = $true }
            continue
        }
        if ($collecting) { $section.Add($line.TrimEnd()) }
    }
    if (-not $collecting) { return $null }

    # Drop the blank lines around the section, keep the ones inside it.
    while ($section.Count -gt 0 -and -not $section[0].Trim())                 { $section.RemoveAt(0) }
    while ($section.Count -gt 0 -and -not $section[$section.Count - 1].Trim()) { $section.RemoveAt($section.Count - 1) }
    if ($section.Count -eq 0) { return $null }
    return $section
}

$newVersion = $Version -replace "^v", ""
$tag        = "v$newVersion"
# 1.0.1-beta leads up to 1.0.1 and carries its notes: the section is written
# once, under the version it belongs to.
$baseVersion = $newVersion.Split("-")[0]

# Resolve -OutFile while we are still in the caller's directory: the script
# steps into the repository root below, and a path already rooted must not
# be glued behind it.
$outPath = $null
if ($OutFile) {
    if ([System.IO.Path]::IsPathRooted($OutFile)) {
        $outPath = $OutFile
    } else {
        $outPath = Join-Path (Get-Location).Path $OutFile
    }
    $outPath = [System.IO.Path]::GetFullPath($outPath)
}

Push-Location $PSScriptRoot
try {
    if (-not (Invoke-Git rev-parse --is-inside-work-tree).Ok) {
        throw "not a git work tree: $PSScriptRoot"
    }
    if ((Invoke-Git rev-parse --is-shallow-repository).Output -eq "true") {
        throw "this is a shallow clone, so there is no history to read.`n  In the workflow, check out with: actions/checkout@v4 with fetch-depth: 0"
    }

    if (-not $Repo) {
        $url = (Invoke-Git remote get-url origin).Output
        if ($url -match "github\.com[:/](?<slug>[^/]+/[^/]+?)(\.git)?$") { $Repo = $matches.slug }
    }
    if (-not $File) { $File = Join-Path $PSScriptRoot "CHANGELOG.md" }

    # Prefer the tag when it already exists: a tag push builds exactly that
    # commit, which need not be the tip of the branch any more.
    $to = if ((Invoke-Git tag --list $tag).Output) { $tag } else { "HEAD" }

    if (-not $Since) {
        $described = Invoke-Git describe --tags --abbrev=0 "$to^"
        if ($described.Ok) { $Since = $described.Output }
    }

    $body = New-Object System.Collections.Generic.List[string]
    $body.Add("## DeckUI $newVersion")
    $body.Add("")

    $section = $null
    $used    = $newVersion
    if (-not $FromCommits) {
        $section = Get-HandwrittenSection $File $newVersion
        if (-not $section -and $baseVersion -ne $newVersion) {
            $section = Get-HandwrittenSection $File $baseVersion
            if ($section) { $used = $baseVersion }
        }
    }

    if ($section) {
        Write-Host ("  from {0}, section {1}" -f (Split-Path $File -Leaf), $used) -ForegroundColor Green
        $section | ForEach-Object { $body.Add($_) }
        $count = @($section | Where-Object { $_.Trim() }).Count
    } else {
        if (-not $FromCommits) {
            $wanted = if ($baseVersion -ne $newVersion) { "$newVersion' or '## $baseVersion" } else { $newVersion }
            Write-Host ("  note: no section '## {0}' in {1}, falling back to the commits" -f $wanted, (Split-Path $File -Leaf)) -ForegroundColor Yellow
        }

        $lines = @()
        if ($Since) {
            Write-Host ("  commits in {0}..{1}" -f $Since, $to)
            $found = Invoke-Git log --no-merges --pretty=format:%s "$Since..$to"
            if (-not $found.Ok) { throw "cannot read the range $Since..$to - is '$Since' a tag in this repository?" }
            $lines = @($found.Output | Where-Object { $_.Trim() } | ForEach-Object { "- " + $_.Trim() })
        } else {
            Write-Host "  no earlier tag found, writing a first-release line" -ForegroundColor Yellow
        }

        if ($lines.Count -gt 0) {
            $lines | ForEach-Object { $body.Add($_) }
        } elseif ($Since) {
            # A tag on the same commit as the last one, or a re-release.
            $body.Add("No code changes since $Since.")
            Write-Host "  note: no commits in that range" -ForegroundColor Yellow
        } else {
            $body.Add("First public release.")
        }
        $count = $lines.Count
    }

    if ($Repo) {
        $body.Add("")
        if ($Since) {
            $body.Add("[All changes since $Since](https://github.com/$Repo/compare/$Since...$tag)")
        } else {
            $body.Add("[Source and issue tracker](https://github.com/$Repo)")
        }
    }

    $text = ($body -join "`n") + "`n"

    $word = if ($count -eq 1) { "line" } else { "lines" }
    Write-Host ("  {0} {1}" -f $count, $word)
    if ($outPath) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($outPath, $text, $utf8NoBom)
        Write-Host ("  written to {0}" -f $outPath)
    } else {
        Write-Output $text
    }
}
finally {
    Pop-Location
}
