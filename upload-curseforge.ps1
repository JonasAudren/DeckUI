<#
    upload-curseforge.ps1 - send a built zip to the CurseForge project.

    The API is documented at
    https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-api

        POST https://wow.curseforge.com/api/projects/<id>/upload-file
        header  X-Api-Token
        body    multipart/form-data with "metadata" (JSON) and "file"

    gameVersions wants numeric ids, not "12.1.0", so the ids are looked up
    through GET /api/game/versions and matched by name. The name is derived
    from the ## Interface number unless -GameVersion says otherwise.

    The token is read from the CF_API_TOKEN environment variable and is never
    passed on the command line, so it stays out of shell history and logs.

    Needs PowerShell 7 (pwsh) for Invoke-RestMethod -Form; Windows PowerShell
    5.1 cannot do multipart. GitHub's runners have pwsh preinstalled.

    Usage:  pwsh ./upload-curseforge.ps1 -Zip dist/DeckUI-1.0.0.zip `
                -ProjectId 1699742 -ReleaseType beta -Interface 120100 -DryRun
#>

param(
    [Parameter(Mandatory)] [string]$Zip,
    [Parameter(Mandatory)] [string]$ProjectId,
    [Parameter(Mandatory)] [ValidateSet("release", "beta", "alpha")] [string]$ReleaseType,

    # Either give the interface number and let the game version be derived,
    # or name the version directly when the derived one is not what you want.
    [string]$Interface,
    [string]$GameVersion,

    [string]$Changelog = "",
    [ValidateSet("text", "html", "markdown")] [string]$ChangelogType = "markdown",
    [string]$DisplayName,

    # Do everything except the upload, and print what would have been sent.
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Zip)) { throw "no such file: $Zip" }
if (-not $Interface -and -not $GameVersion) {
    throw "give -Interface (e.g. 120100) or -GameVersion (e.g. 12.1.0)"
}

$token = $env:CF_API_TOKEN
if (-not $token) { throw "CF_API_TOKEN is not set" }

# ## Interface: 120100 means major 12, minor 01, patch 00 -> 12.1.0
function ConvertTo-GameVersionName([string]$iface) {
    if ($iface -notmatch "^\d{5,6}$") { throw "cannot read an interface number from '$iface'" }
    $major = [int]$iface.Substring(0, $iface.Length - 4)
    $minor = [int]$iface.Substring($iface.Length - 4, 2)
    $patch = [int]$iface.Substring($iface.Length - 2, 2)
    return "$major.$minor.$patch"
}

if (-not $GameVersion) {
    $GameVersion = ConvertTo-GameVersionName $Interface
    Write-Host ("  interface {0} -> game version {1}" -f $Interface, $GameVersion)
}

$headers = @{ "X-Api-Token" = $token }

Write-Host "  asking CurseForge for its game version list"
$all = Invoke-RestMethod -Uri "https://wow.curseforge.com/api/game/versions" -Headers $headers

$matching = @($all | Where-Object { $_.name -eq $GameVersion })
if ($matching.Count -eq 0) {
    # Do not guess a different version: an addon filed under the wrong game
    # version is worse than a failed upload. Show what is on offer instead.
    $recent = ($all | Sort-Object -Property id -Descending | Select-Object -First 12 |
               ForEach-Object { "{0} (id {1})" -f $_.name, $_.id }) -join "`n    "
    throw "CurseForge lists no game version named '$GameVersion'.`n  The newest it offers:`n    $recent`n  Pass the right one with -GameVersion."
}
$ids = @($matching | ForEach-Object { $_.id })
Write-Host ("  game version {0} -> id(s) {1}" -f $GameVersion, ($ids -join ", "))

$metadata = [ordered]@{
    changelog     = $Changelog
    changelogType = $ChangelogType
    releaseType   = $ReleaseType
    gameVersions  = $ids
}
if ($DisplayName) { $metadata["displayName"] = $DisplayName }
$json = $metadata | ConvertTo-Json -Compress

$file = Get-Item $Zip
Write-Host ""
Write-Host ("  project    {0}" -f $ProjectId)
Write-Host ("  file       {0}  ({1:N0} KB)" -f $file.Name, ($file.Length / 1KB))
Write-Host ("  metadata   {0}" -f $json)
Write-Host ""

if ($DryRun) {
    Write-Host "  dry run, nothing uploaded" -ForegroundColor Yellow
    return
}

$result = Invoke-RestMethod -Uri "https://wow.curseforge.com/api/projects/$ProjectId/upload-file" `
    -Method Post -Headers $headers -Form @{ metadata = $json; file = $file }

Write-Host ("  uploaded, file id {0}" -f $result.id) -ForegroundColor Green
if ($env:GITHUB_OUTPUT) { Add-Content $env:GITHUB_OUTPUT "file_id=$($result.id)" }
