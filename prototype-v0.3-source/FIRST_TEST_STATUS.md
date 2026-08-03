# AI Dialogue Prototype v0.3

This branch contains the first-test integration slice based on the uploaded Visual Studio project.

## Implemented

- OBSE plugin waits for `kMessage_DataLoaded` before starting interaction.
- Native Windows F8 hotkey registration (no DiUI/MadMCM dependency).
- F8 launches `Interaction/AI_Dialogue_Interaction.ps1`.
- The interaction window accepts a manual NPC name and player message.
- The existing `AI_Dialogue_Bridge.exe` is invoked with request/response files.
- The reply is displayed in a Windows message box.
- Plugin and interaction logs are written under `OBSE/Plugins/AI_Dialogue/Logs`.
- Build and packaging scripts are included.

## First-test scope

This test validates:

1. GSLoader -> MagicLoader -> OBSE64 loads the plugin.
2. The plugin receives `DataLoaded`.
3. F8 is registered.
4. The interaction window opens.
5. The bridge reads the Windows Credential Manager API key.
6. The OpenAI response is returned and displayed.

Automatic NPC detection and injection into the native Oblivion dialogue-topic list are not included in this first test.

## Build

Run from PowerShell on Windows with Visual Studio 2022 installed:

```powershell
.\Build-Prototype-v0.3.ps1 -Configuration Release
.\Package-Prototype-v0.3.ps1 -Configuration Release
```

The package script creates `AI_Dialogue_OBSE64_0.3.0_Prototype.zip`.
