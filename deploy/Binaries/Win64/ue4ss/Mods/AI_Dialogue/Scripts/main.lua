-- AI Dialogue overlay for Oblivion Remastered.
-- MadMCM loads after alphabetically earlier UE4SS mods, so initialization is deferred
-- until both its DiUI library and UEHelpers are available.

package.path = ".\\ue4ss\\Mods\\shared\\UEHelpers\\?.lua;.\\ue4ss\\Mods\\shared\\MadMCMUtilities\\?.lua;.\\ue4ss\\Mods\\MadMCM\\Scripts\\?.lua;" .. package.path

local started = false
local lastInitializationError = ""
local retainedHooks = {}

local function StartMod()
    if started then return true end

    local okHelpers, UEHelpers = pcall(require, "UEHelpers")
    if not okHelpers then
        lastInitializationError = "UEHelpers=" .. tostring(UEHelpers)
        return false
    end

    local okController, controller = pcall(function() return UEHelpers.GetPlayerController() end)
    if not okController or not controller or not controller:IsValid() then
        lastInitializationError = "PlayerController is not ready"
        return false
    end

    local okDiUI, DiUI = pcall(require, "DiUI")
    if not okDiUI then
        lastInitializationError = "DiUI=" .. tostring(DiUI)
        return false
    end

    started = true

local settings = {
    Enabled = true,
    ModelPreset = 1,
    MaxOutputTokens = 220,
    InjectDialogueButton = false,
    DialogueButtonLabel = 1,
    DialogueButtonWidth = 180,
}

local hasMCM, MCM = pcall(require, "MadMCMUtilities")
if hasMCM then
    MCM.RegisterMCMConsoleSetter("AI_Dialogue_Config", settings)
end

local window = nil
local visible = false
local npcInput = nil
local playerInput = nil
local responseText = nil
local statusText = nil

local function modelForPreset()
    if tonumber(settings.ModelPreset) == 2 then return "gpt-5.4-nano" end
    return "gpt-5.4-mini"
end

local function safeSetText(widget, text)
    if widget and widget:IsValid() then
        pcall(function() widget:SetText(FText(text)) end)
    end
end

local function addSizedChild(parent, child, width, height)
    if not child or not child:IsValid() then
        error("DiUI returned an invalid child widget")
    end

    -- USizeBox construction is broken with this installed DiUI/UE4SS combination.
    -- Add the widget directly and apply slot padding where supported.
    local slot = parent:AddChildToVerticalBox(child)
    if slot and slot:IsValid() then
        pcall(function() slot:SetPadding({Left=4, Right=4, Top=3, Bottom=3}) end)
        pcall(function() slot:SetHorizontalAlignment(3) end) -- Fill
    end
    return child
end

local function addLabel(parent, text)
    return addSizedChild(parent, window:CreateTextBlock(text), 760, 26)
end

local function inDialogue()
    local controller = UEHelpers.GetPlayerController()
    if not controller or not controller:IsValid() then return false end

    local candidates = { "bIsInDialogue", "bInDialogue", "IsInDialogue", "IsMoveInputIgnored" }
    for _, memberName in ipairs(candidates) do
        local ok, value = pcall(function()
            local member = controller[memberName]
            if type(member) == "function" then return member(controller) end
            return member
        end)
        if ok and value == true then return true end
    end
    return false
end

local function closeWindow()
    if not window or not window.InternalWidget or not window.InternalWidget:IsValid() then return end
    window:Hide()
    visible = false
    local controller = UEHelpers.GetPlayerController()
    if controller and controller:IsValid() then
        pcall(function() controller:SwitchToGameInputMappings() end)
        pcall(function() controller.bShowMouseCursor = false end)
    end
end

local function sanitizeSingleLine(value)
    value = tostring(value or "")
    value = value:gsub("[\r\n]", " ")
    return value
end

local function inputText(widget)
    if not widget or not widget:IsValid() then return "" end
    local ok, text = pcall(function() return widget:GetText():ToString() end)
    return ok and sanitizeSingleLine(text) or ""
end

local function submitQuestion()
    local message = inputText(playerInput)
    if message == "" then
        safeSetText(statusText, "Enter a question first.")
        return
    end

    local npc = inputText(npcInput)
    if npc == "" then npc = "the NPC currently speaking to the player" end

    local token = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    local requestPath = "OBSE\\Plugins\\AI_Dialogue\\Runtime\\requests\\" .. token .. ".request"
    local responsePath = "OBSE\\Plugins\\AI_Dialogue\\Runtime\\responses\\" .. token .. ".response"

    local requestFile = io.open(requestPath, "w")
    if not requestFile then
        safeSetText(statusText, "Could not create the AI request file. Reinstall the bridge files.")
        return
    end
    requestFile:write("NPC=", npc, "\n")
    requestFile:write("MODEL=", modelForPreset(), "\n")
    requestFile:write("MAX_OUTPUT_TOKENS=", tostring(settings.MaxOutputTokens or 220), "\n")
    requestFile:write("---MESSAGE---\n", message)
    requestFile:close()

    safeSetText(statusText, "Thinking...")
    safeSetText(responseText, "")
    local command = "start \"\" /b \"OBSE\\Plugins\\AI_Dialogue\\AI_Dialogue_Bridge.exe\" --request \"" ..
        requestPath .. "\" --response \"" .. responsePath .. "\""
    os.execute(command)

    LoopAsync(250, function()
        local responseFile = io.open(responsePath, "r")
        if not responseFile then return false end
        local response = responseFile:read("*a")
        responseFile:close()
        os.remove(responsePath)
        safeSetText(responseText, response)
        safeSetText(statusText, "")
        return true
    end)
end

local function createWindow()
    if window and window.InternalWidget and window.InternalWidget:IsValid() then return true end

    local ok, errorMessage = pcall(function()
        window = DiUI.DiWindow:New("AIDialogue", "AI Dialogue", { X = 400, Y = 200 })
        local box = window.InternalVBox

        addLabel(box, "AI Dialogue - Ask the current NPC anything")
        addLabel(box, "NPC name (optional; leave blank to use a generic in-character prompt):")
        npcInput = addSizedChild(box, window:CreateEditableTextBox(), 760, 34)
        pcall(function() npcInput:SetHintText(FText("e.g. Baurus")) end)

        addLabel(box, "What do you want to ask?")
        playerInput = addSizedChild(box, window:CreateEditableTextBox(), 760, 34)
        pcall(function() playerInput:SetHintText(FText("Type your question here")) end)

        local controls = window:CreateHorizontalBox()
        if not controls or not controls:IsValid() then
            error("DiUI could not create the controls row")
        end

        local sendButton = window:CreateButton("Send", submitQuestion)
        local closeButton = window:CreateButton("Close", closeWindow)
        if not sendButton or not sendButton:IsValid() then
            error("DiUI could not create the Send button")
        end
        if not closeButton or not closeButton:IsValid() then
            error("DiUI could not create the Close button")
        end

        local sendSlot = controls:AddChildToHorizontalBox(sendButton)
        if sendSlot and sendSlot:IsValid() then
            pcall(function() sendSlot:SetPadding({Left=4, Right=4, Top=3, Bottom=3}) end)
        end

        local closeSlot = controls:AddChildToHorizontalBox(closeButton)
        if closeSlot and closeSlot:IsValid() then
            pcall(function() closeSlot:SetPadding({Left=4, Right=4, Top=3, Bottom=3}) end)
        end

        addSizedChild(box, controls, 760, 42)

        statusText = addLabel(box, "")
        responseText = window:CreateTextBlock("")
        pcall(function() responseText:SetAutoWrapText(true) end)
        addSizedChild(box, responseText, 760, 240)
        window:Hide()
    end)

    if not ok then
        print("[AI Dialogue] Failed to create overlay: " .. tostring(errorMessage))
        window = nil
    end
    return window ~= nil
end

local function openWindow()
    if visible then
        closeWindow()
        return
    end
    if not settings.Enabled then
        print("[AI Dialogue] The overlay is disabled in MadMCM.")
        return
    end
    if not createWindow() then return end

    if not inDialogue() then
        safeSetText(statusText, "Open this while a dialogue menu is active.")
    else
        safeSetText(statusText, "")
    end
    window:Show()
    visible = true

    local controller = UEHelpers.GetPlayerController()
    if controller and controller:IsValid() then
        pcall(function() controller:SwitchToUIInputMappings() end)
        pcall(function() controller.bShowMouseCursor = true end)
    end
    if playerInput and playerInput:IsValid() then
        pcall(function() playerInput:SetKeyboardFocus() end)
    end
end

-- Better Dialogue Menu uses this widget and a horizontal service-control row.
-- The option is deliberately a button in that row, not a fake quest topic: the
-- game's internal response data structures are not publicly exposed.
local injectedMenus = {}
local dialogueHookPath = "/Game/UI/Modern/GameMenuLayer/Dialog/WBP_ModernMenu_Dialog.WBP_ModernMenu_Dialog_C:BP_OnActivated"

local function isValid(widget)
    local ok, result = pcall(function() return widget and widget:IsValid() end)
    return ok and result == true
end

local function findDialogueButtonLayout(dialog)
    local layout = nil
    pcall(function()
        local tree = dialog.WidgetTree
        if tree and tree:IsValid() then
            layout = tree:FindWidget(FName("dialog_button_layout"))
        end
    end)
    if not isValid(layout) then
        pcall(function() layout = dialog.dialog_button_layout end)
    end
    return isValid(layout) and layout or nil
end

local function dialogueButtonText()
    local preset = tonumber(settings.DialogueButtonLabel) or 1
    if preset == 2 then return "Ask Anything" end
    if preset == 3 then return "Speak Freely" end
    return "AI Dialogue"
end

local function dialogueButtonWidth()
    local width = tonumber(settings.DialogueButtonWidth) or 180
    return math.max(120, math.min(320, width))
end

local function addDialogueButton(dialog)
    if not settings.InjectDialogueButton then return end
    if not isValid(dialog) then return end

    local menuName = dialog:GetFullName()
    if injectedMenus[menuName] then return end

    local layout = findDialogueButtonLayout(dialog)
    if not layout then
        print("[AI Dialogue] Dialogue menu is active but dialog_button_layout was not found.")
        return
    end

    local button = DiUI.CreateButton(dialog, dialogueButtonText(), function()
        openWindow()
    end)
    if not isValid(button) then
        print("[AI Dialogue] Could not create the AI Dialogue menu button.")
        return
    end

    local sizeBox = DiUI.CreateSizeBox(dialog)
    if not isValid(sizeBox) then
        print("[AI Dialogue] Could not create the AI Dialogue button container.")
        return
    end

    sizeBox:SetWidthOverride(dialogueButtonWidth())
    sizeBox:SetHeightOverride(38)
    sizeBox:AddChild(button)
    layout:AddChildToHorizontalBox(sizeBox)
    button:SetVisibility(0)
    injectedMenus[menuName] = true
    print("[AI Dialogue] Added AI Dialogue to the dialogue service row.")
end

local function onDialogueMenuActivated(ctx)
    local ok, dialog = pcall(function() return ctx and ctx:get() end)
    if not ok or not isValid(dialog) then return end

    ExecuteInGameThread(function()
        local injected, errorMessage = pcall(addDialogueButton, dialog)
        if not injected then
            print("[AI Dialogue] Failed to add dialogue menu button: " .. tostring(errorMessage))
        end
    end)
end

if settings.InjectDialogueButton then
    local dialogueHookAttempts = 0
    local dialogueHookCallback = onDialogueMenuActivated
    retainedHooks[#retainedHooks + 1] = dialogueHookCallback
    LoopAsync(2000, function()
        dialogueHookAttempts = dialogueHookAttempts + 1
        local installed, errorMessage = pcall(RegisterHook, dialogueHookPath, dialogueHookCallback)
        if installed then
            print("[AI Dialogue] Dialogue-menu button hook registered.")
            return true
        end
        if dialogueHookAttempts >= 30 then
            print("[AI Dialogue] Dialogue-menu button hook was unavailable: " .. tostring(errorMessage))
            return true
        end
        return false
    end)
else
    print("[AI Dialogue] Dialogue-menu button hook disabled by configuration.")
end

RegisterConsoleCommandHandler("AI_Dialogue_Open", function()
    openWindow()
    return true
end)

RegisterKeyBind(Key.F8, openWindow)

    print("[AI Dialogue] DiUI compatibility mode active (no SizeBox widgets).")
    print("[AI Dialogue] UE4SS overlay loaded. Use F8 while speaking to an NPC.")
    return true
end

local initializationAttempts = 0
LoopAsync(500, function()
    initializationAttempts = initializationAttempts + 1
    if StartMod() then return true end

    if initializationAttempts >= 120 then
        print("[AI Dialogue] Required UI modules were unavailable after 60 seconds: " .. lastInitializationError)
        return true
    end

    return false
end)

