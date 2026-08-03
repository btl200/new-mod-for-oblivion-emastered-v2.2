param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$gameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Oblivion Remastered'
$binDir = Join-Path $gameRoot 'OblivionRemastered\Binaries\Win64'
$dataDir = Join-Path $gameRoot 'OblivionRemastered\Content\Dev\ObvData\Data'
$pluginsFile = Join-Path $dataDir 'Plugins.txt'
$verifiedPluginsFile = Join-Path $PSScriptRoot 'Plugins.verified.txt'
$gsLoader = Join-Path $gameRoot 'GSLoader.exe'
$magicLoader = Join-Path $gameRoot 'MagicLoader\MagicLoader.exe'
$obseLoader = Join-Path $binDir 'obse64_loader.exe'
$repakBindSource = Join-Path $gameRoot 'repak_bind.dll'
$repakBindForMagicLoader = Join-Path $gameRoot 'MagicLoader\repak_bind.dll'
$logFile = Join-Path $PSScriptRoot 'SafeLaunch-OBSE.log'
$configDir = 'C:\Users\Brnsl\Documents\My Games\Oblivion Remastered\Saved\Config\Windows'
$altarFile = Join-Path $configDir 'Altar.ini'
$altarGsLoaderBackup = Join-Path $configDir 'Altar-GSLoaderBackup.ini'
$verifiedTemplateHash = '949EEDDE5B79D82D6954CC6D2AB79B43401F901C649616B25F4B7466A9DCDD65'
$obseDir = Join-Path $binDir 'OBSE'

function Write-GuardLog {
    param([string]$Message)
    $line = '{0:o} {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Show-GuardError {
    param([string]$Message)
    Write-GuardLog "ERROR: $Message"
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            $Message,
            'Oblivion Remastered safe-launch error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch {
        Write-Error $Message
    }
}

function Get-LatestObseLogSnapshot {
    if (-not (Test-Path -LiteralPath $obseDir -PathType Container)) {
        return $null
    }

    Get-ChildItem -LiteralPath $obseDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.txt' } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1 FullName, LastWriteTimeUtc, Length
}

try {
    if (Get-Process -Name 'OblivionRemastered-Win64-Shipping' -ErrorAction SilentlyContinue) {
        throw 'The game is already running.'
    }

    foreach ($required in @(
        $verifiedPluginsFile,
        $gsLoader,
        $magicLoader,
        $obseLoader,
        $repakBindSource,
        $altarFile
    )) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Required launcher file is missing: $required"
        }
    }

    $repairRepakBind = -not (Test-Path -LiteralPath $repakBindForMagicLoader -PathType Leaf)
    if (-not $repairRepakBind) {
        $sourceRepakHash = (Get-FileHash -LiteralPath $repakBindSource -Algorithm SHA256).Hash
        $magicRepakHash = (Get-FileHash -LiteralPath $repakBindForMagicLoader -Algorithm SHA256).Hash
        $repairRepakBind = $sourceRepakHash -ne $magicRepakHash
    }
    if ($repairRepakBind) {
        Copy-Item -LiteralPath $repakBindSource -Destination $repakBindForMagicLoader -Force
        Write-GuardLog "Restored MagicLoader native dependency: $repakBindForMagicLoader"
    }

    if (-not (Test-Path -LiteralPath $altarGsLoaderBackup -PathType Leaf)) {
        Copy-Item -LiteralPath $altarFile -Destination $altarGsLoaderBackup
        Write-GuardLog "Recreated GSLoader Altar backup: $altarGsLoaderBackup"
    }

    $templateHash = (Get-FileHash -LiteralPath $verifiedPluginsFile -Algorithm SHA256).Hash
    if ($templateHash -ne $verifiedTemplateHash) {
        throw "The verified plugin-order template has changed. Expected $verifiedTemplateHash but found $templateHash."
    }

    $pluginLines = @(Get-Content -LiteralPath $verifiedPluginsFile)
    $entries = @($pluginLines | Where-Object { $_ -and -not $_.StartsWith('##') })
    $normalized = @($entries | ForEach-Object { $_.TrimStart('#').ToLowerInvariant() })
    $duplicates = @($normalized | Group-Object | Where-Object { $_.Count -gt 1 })

    if ($entries.Count -ne 225) {
        throw "The verified plugin order contains $($entries.Count) entries instead of 225."
    }
    if ($entries[0] -ne 'Oblivion.esm') {
        throw 'Oblivion.esm is not first in the verified plugin order.'
    }
    if (@($normalized | Where-Object { $_ -eq 'oblivion.esm' }).Count -ne 1) {
        throw 'The verified plugin order does not contain exactly one Oblivion.esm entry.'
    }
    if ($duplicates.Count -ne 0) {
        throw 'The verified plugin order contains duplicate plugin names.'
    }

    $missing = @()
    foreach ($entry in $entries) {
        if ($entry.StartsWith('#')) {
            continue
        }
        $pluginPath = Join-Path $dataDir $entry
        if (-not (Test-Path -LiteralPath $pluginPath -PathType Leaf)) {
            $missing += $entry
        }
    }
    if ($missing.Count -ne 0) {
        throw "Deployment is incomplete. Missing enabled plugins: $($missing -join ', ')"
    }

    Start-Sleep -Milliseconds 350
    $verifiedBytes = [System.IO.File]::ReadAllBytes($verifiedPluginsFile)
    [System.IO.File]::WriteAllBytes($pluginsFile, $verifiedBytes)

    $deployedHash = (Get-FileHash -LiteralPath $pluginsFile -Algorithm SHA256).Hash
    if ($deployedHash -ne $verifiedTemplateHash) {
        throw "Could not restore the verified Plugins.txt. Found hash $deployedHash."
    }

    Write-GuardLog "Validated OBSE loader: $obseLoader"
    Write-GuardLog "Validated MagicLoader: $magicLoader"

    if ($ValidateOnly) {
        Write-GuardLog 'OK: validation-only run restored Plugins.txt and verified GSLoader, MagicLoader, and OBSE64.'
        Write-Host 'Validation passed.' -ForegroundColor Green
        exit 0
    }

    $beforeLog = Get-LatestObseLogSnapshot
    $launchTimeUtc = [DateTime]::UtcNow

    Write-GuardLog 'OK: restored Plugins.txt; launching GSLoader with the complete MagicLoader executable path.'
    Write-GuardLog 'Expected chain: LaunchGuard -> GSLoader -> MagicLoader -> OBSE64 -> game.'

    Push-Location -LiteralPath $gameRoot
    try {
        & $gsLoader $magicLoader
        $loaderExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    Write-GuardLog "GSLoader exited with code $loaderExitCode."

    Start-Sleep -Seconds 2
    $afterLog = Get-LatestObseLogSnapshot

    if ($afterLog -and $afterLog.LastWriteTimeUtc -ge $launchTimeUtc.AddSeconds(-2)) {
        Write-GuardLog "OBSE activity detected after launch: $($afterLog.FullName) at $($afterLog.LastWriteTimeUtc.ToString('o'))."
    } elseif ($afterLog) {
        Write-GuardLog "WARNING: No freshly updated OBSE log was detected. Latest log: $($afterLog.FullName), modified $($afterLog.LastWriteTimeUtc.ToString('o'))."
    } else {
        Write-GuardLog 'WARNING: No OBSE log file was found after launch.'
    }

    exit $loaderExitCode
}
catch {
    Show-GuardError $_.Exception.Message
    exit 1
}
