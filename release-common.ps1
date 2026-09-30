<#
Shared by package.ps1 and bump-version.ps1 (dot-sourced): the addon
folders a release is made of, and reading a .toc header. A new module is
added here once instead of in both scripts.

The list stays explicit rather than being read off the folders: package.ps1
checks the archive against it, and a stray DeckUI_* folder with a .toc
must not ship just because it exists.
#>

$addons = @("DeckUI", "DeckUI_Orbs", "DeckUI_Cross", "DeckUI_Spec", "DeckUI_Bags", "DeckUI_Quests", "DeckUI_Map")

function Get-TocField($path, $field) {
    foreach ($line in Get-Content $path) {
        if ($line -match "^##\s+$field\s*:\s*(.+?)\s*$") { return $matches[1] }
    }
    return $null
}
