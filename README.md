# AI Dialogue Stability Test

**Direction: Option B**

This repository is being used to stage the Oblivion Remastered AI Dialogue stability test build.

Option B means the current test direction is:

- OBSE64 plugin
- bridge executable
- setup utility
- UE4SS/F8 overlay path
- no native ESP/Rumors-style topic yet

## Stability test goal

This test build disables the unstable injected Better Dialogue Menu button and keeps the F8 overlay path working. The purpose is to isolate the old-save crash before adding a proper dialogue-topic workflow later.

## Build the stability deploy ZIP on Windows

Put this file in your Downloads folder:

```text
AI_Dialogue_OBSE64_0.2.2_Release.zip
```

Then open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/btl200/new-mod-for-oblivion-emastered-v2.2/main/tools/Build-Stability-Test.ps1" -OutFile "$env:USERPROFILE\Downloads\Build-Stability-Test.ps1"
& "$env:USERPROFILE\Downloads\Build-Stability-Test.ps1"
```

The script creates:

```text
%USERPROFILE%\Downloads\AI_Dialogue_0.2.2_Stability_Test_Deploy.zip
```

## Install test ZIP

Extract the generated ZIP into the Oblivion Remastered game root, merge folders, overwrite files, launch through `obse64_loader.exe`, load your old save, talk to an NPC, then press **F8**.
