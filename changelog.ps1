<#
    changelog.ps1 - turn the commits since the last tag into a changelog.

    CurseForge shows this text on the file's page and in the app, so it used
    to be worth little: the release workflow sent a bare link to the commit
    list, which nobody clicks. The commit subjects in this repository are
    written as whole sentences, so they serve as the changelog directly.

    The range is "everything since the previous tag". That tag is found with
    git describe, so it is the previous tag on this branch's history rather
    than whatever sorts highest. Without any earlier tag - the first release
    - there is nothing to diff against, and a short line goes out instead of
    dozens of commits from the initial development.

    Needs the full history: a shallow clone has no tags and no earlier
    commits, so the script says so rather than writing an empty list.

    Usage:  pwsh ./changelog.ps1 1.0.1
            pwsh ./changelog.ps1 1.0.1 -Since v1.0.0
            pwsh ./changelog.ps1 1.0.1 -OutFile changelog.md
#>

param(
    # Version this changelog is for, e.g. 1.0.1. A leading v is stripped.
    [Parameter(Mandatory, Position = 0)] [string]$Version,

    # Start of the range, a tag like v1.0.0. Found with git describe when
    # left out.
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
        return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = $output }
    } finally {
        $ErrorActionPreference = $previous
    }
}

$newVersion = $Version -replace "^v", ""
$tag        = "v$newVersion"

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

    # Prefer the tag when it already exists: a tag push builds exactly that
    # commit, which need not be the tip of the branch any more.
    $to = if ((Invoke-Git tag --list $tag).Output) { $tag } else { "HEAD" }

    if (-not $Since) {
        $described = Invoke-Git describe --tags --abbrev=0 "$to^"
        if ($described.Ok) { $Since = $described.Output }
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

    $body = New-Object System.Collections.Generic.List[string]
    $body.Add("## DeckUI $newVersion")
    $body.Add("")

    if ($lines.Count -gt 0) {
        $lines | ForEach-Object { $body.Add($_) }
        if ($Repo) {
            $body.Add("")
            $body.Add("[All changes since $Since](https://github.com/$Repo/compare/$Since...$tag)")
        }
    } elseif ($Since) {
        # A tag on the same commit as the last one, or a re-release.
        $body.Add("No code changes since $Since.")
        Write-Host "  note: no commits in that range" -ForegroundColor Yellow
    } else {
        $body.Add("First public release.")
        if ($Repo) {
            $body.Add("")
            $body.Add("[Source and issue tracker](https://github.com/$Repo)")
        }
    }

    $text = ($body -join "`n") + "`n"

    $word = if ($lines.Count -eq 1) { "entry" } else { "entries" }
    Write-Host ("  {0} {1}" -f $lines.Count, $word)
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
