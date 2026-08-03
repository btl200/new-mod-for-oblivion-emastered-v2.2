param(
    [string]$LaunchGuardPath = "$env:USERPROFILE\Desktop\LaunchGuard\Launch-Oblivion-GSLoader.ps1"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LaunchGuardPath -PathType Leaf)) {
    throw "LaunchGuard script not found: $LaunchGuardPath"
}

$backupPath = "$LaunchGuardPath.before-obse-chain.bak"
Copy-Item -LiteralPath $LaunchGuardPath -Destination $backupPath -Force

$text = [System.IO.File]::ReadAllText($LaunchGuardPath)

$magicLoaderLine = "$magicLoader = Join-Path $gameRoot 'MagicLoader\MagicLoader.exe'"
$obseLoaderLine = "$obseLoader = Join-Path $binDir 'obse64_loader.exe'"

if (-not $text.Contains($magicLoaderLine)) {
    throw 'Could not find the expected MagicLoader path declaration. The launcher script may have changed.'
}

if (-not $text.Contains($obseLoaderLine)) {
    $text = $text.Replace($magicLoaderLine, "$magicLoaderLine`r`n$obseLoaderLine")
}

$oldRequired = 'foreach ($required in @($verifiedPluginsFile, $gsLoader, $magicLoader, $repakBindSource, $altarFile))'
$newRequired = 'foreach ($required in @($verifiedPluginsFile, $gsLoader, $magicLoader, $obseLoader, $repakBindSource, $altarFile))'

if ($text.Contains($oldRequired)) {
    $text = $text.Replace($oldRequired, $newRequired)
} elseif (-not $text.Contains($newRequired)) {
    throw 'Could not find the expected required-file validation list.'
}

$oldLog = 'Write-GuardLog "OK: restored Plugins.txt; launching root GSLoader with target=MagicLoader"'
$newLog = 'Write-GuardLog "OK: restored Plugins.txt; launching GSLoader with full MagicLoader path. MagicLoader should auto-launch OBSE64."'
$text = $text.Replace($oldLog, $newLog)

$oldLaunch = "& $gsLoader 'MagicLoader'"
$newLaunch = '& $gsLoader $magicLoader'

if ($text.Contains($oldLaunch)) {
    $text = $text.Replace($oldLaunch, $newLaunch)
} elseif (-not $text.Contains($newLaunch)) {
    throw 'Could not find the expected GSLoader launch command.'
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($LaunchGuardPath, $text, $utf8NoBom)

Write-Host 'LaunchGuard patched successfully.' -ForegroundColor Green
Write-Host "Patched: $LaunchGuardPath"
Write-Host "Backup:  $backupPath"
Write-Host ''
Write-Host 'Expected launch chain:'
Write-Host '  LaunchGuard -> GSLoader -> MagicLoader -> OBSE64 -> Game'
Write-Host ''
Write-Host 'Run the normal Safe GSLoader + MagicLoader desktop shortcut to test.'
