param(
    [string]$SourceZip = "$env:USERPROFILE\Downloads\AI_Dialogue_OBSE64_0.2.2_Release.zip",
    [string]$OutZip = "$env:USERPROFILE\Downloads\AI_Dialogue_0.2.2_Stability_Test_Deploy.zip"
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
    Write-Host "[AI Dialogue Stability] $Message"
}

if (-not (Test-Path $SourceZip)) {
    throw "Source ZIP not found: $SourceZip`nPut AI_Dialogue_OBSE64_0.2.2_Release.zip in Downloads or pass -SourceZip with the full path."
}

$workRoot = Join-Path $env:TEMP ("AI_Dialogue_Stability_" + [guid]::NewGuid().ToString("N"))
$extractRoot = Join-Path $workRoot "extract"
$stageRoot = Join-Path $workRoot "stage"

Write-Step "Extracting source package"
New-Item -ItemType Directory -Force -Path $extractRoot, $stageRoot | Out-Null
Expand-Archive -Path $SourceZip -DestinationPath $extractRoot -Force

# Some packages contain a single nested root folder. Find the folder that contains Binaries.
$packageRoot = $extractRoot
$binaryRoot = Get-ChildItem -Path $extractRoot -Directory -Recurse -Filter "Binaries" | Select-Object -First 1
if ($binaryRoot) {
    $packageRoot = Split-Path $binaryRoot.FullName -Parent
}

Write-Step "Staging install files"
$stageBinaries = Join-Path $stageRoot "Binaries"
$srcBinaries = Join-Path $packageRoot "Binaries"
if (Test-Path $srcBinaries) {
    Copy-Item -Path $srcBinaries -Destination $stageRoot -Recurse -Force
} else {
    throw "Could not find Binaries folder inside source ZIP."
}

# Runtime folders for bridge request/response files.
$runtime = Join-Path $stageRoot "Binaries\Win64\OBSE\Plugins\AI_Dialogue\Runtime"
New-Item -ItemType Directory -Force -Path (Join-Path $runtime "requests"), (Join-Path $runtime "responses") | Out-Null

# Hard-disable the unstable Better Dialogue Menu injected button path.
$madConfig = Join-Path $stageRoot "Binaries\Win64\MadConfigs\AI Dialogue.ini"
if (Test-Path $madConfig) {
    $ini = Get-Content $madConfig -Raw
    if ($ini -match "InjectDialogueButton") {
        $ini = [regex]::Replace($ini, "(?m)^\s*InjectDialogueButton\s*=\s*.*$", "InjectDialogueButton=false")
    } else {
        $ini += "`r`nInjectDialogueButton=false`r`n"
    }
    Set-Content -Path $madConfig -Value $ini -Encoding UTF8
    Write-Step "Forced InjectDialogueButton=false"
} else {
    Write-Warning "MadMCM config not found: $madConfig"
}

$luaCandidates = Get-ChildItem -Path $stageRoot -Recurse -Filter "main.lua" | Where-Object { $_.FullName -match "AI_Dialogue" }
foreach ($luaFile in $luaCandidates) {
    $lua = Get-Content $luaFile.FullName -Raw
    $original = $lua

    # Force any runtime config assignment off.
    $lua = [regex]::Replace($lua, "(?i)(InjectDialogueButton\s*=\s*)true", '${1}false')

    # Guard hook registration blocks that target Better Dialogue Menu activation.
    if ($lua -match "BP_OnActivated") {
        $lua = $lua -replace "if\s+config\.InjectDialogueButton\s+then", "if false then -- stability test: disabled InjectDialogueButton hook"
        $lua = $lua -replace "if\s+settings\.InjectDialogueButton\s+then", "if false then -- stability test: disabled InjectDialogueButton hook"
        $lua = $lua -replace "if\s+InjectDialogueButton\s+then", "if false then -- stability test: disabled InjectDialogueButton hook"
    }

    if ($lua -ne $original) {
        Set-Content -Path $luaFile.FullName -Value $lua -Encoding UTF8
        Write-Step "Patched Lua hook: $($luaFile.FullName)"
    }
}

# Make a small note inside the package.
$notes = @"
AI Dialogue 0.2.2 Stability Test Deploy

Direction: Option B
- OBSE64 plugin + bridge + UE4SS/F8 overlay path remains the test path.
- Experimental Better Dialogue Menu injected button is disabled.
- This package is intended to isolate the old-save crash.

Install:
1. Close Oblivion Remastered.
2. Extract this ZIP into the Oblivion Remastered game root.
3. Merge folders and overwrite files.
4. Launch through obse64_loader.exe.
5. Load old save, talk to an NPC, press F8.
"@
Set-Content -Path (Join-Path $stageRoot "AI_Dialogue_Stability_Test_README.txt") -Value $notes -Encoding UTF8

if (Test-Path $OutZip) {
    Remove-Item $OutZip -Force
}

Write-Step "Creating deploy ZIP"
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $OutZip -Force

$sha = (Get-FileHash -Path $OutZip -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Step "Done"
Write-Host "Output: $OutZip"
Write-Host "SHA-256: $sha"
