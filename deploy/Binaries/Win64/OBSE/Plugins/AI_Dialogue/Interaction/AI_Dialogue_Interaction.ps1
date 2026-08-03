param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$interactionDir = $PSScriptRoot
$modDir = Split-Path $interactionDir -Parent
$bridge = Join-Path $modDir 'AI_Dialogue_Bridge.exe'
$runtime = Join-Path $modDir 'Runtime'
$requests = Join-Path $runtime 'requests'
$responses = Join-Path $runtime 'responses'
$logs = Join-Path $modDir 'Logs'
$logFile = Join-Path $logs 'Interaction.log'

New-Item -ItemType Directory -Force -Path $requests, $responses, $logs | Out-Null

function Write-InteractionLog {
    param([string]$Message)
    Add-Content -LiteralPath $logFile -Value ('{0:o} {1}' -f (Get-Date), $Message) -Encoding UTF8
}

function Show-ErrorMessage {
    param([string]$Message)
    Write-InteractionLog "ERROR: $Message"
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'AI Dialogue',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

try {
    if (-not (Test-Path -LiteralPath $bridge -PathType Leaf)) {
        throw "Bridge executable not found: $bridge"
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'AI Dialogue'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(620, 430)
    $form.MinimumSize = New-Object System.Drawing.Size(620, 430)
    $form.TopMost = $true

    $npcLabel = New-Object System.Windows.Forms.Label
    $npcLabel.Text = 'NPC name (optional)'
    $npcLabel.Location = New-Object System.Drawing.Point(16, 16)
    $npcLabel.AutoSize = $true
    $form.Controls.Add($npcLabel)

    $npcBox = New-Object System.Windows.Forms.TextBox
    $npcBox.Location = New-Object System.Drawing.Point(16, 40)
    $npcBox.Size = New-Object System.Drawing.Size(570, 24)
    $form.Controls.Add($npcBox)

    $messageLabel = New-Object System.Windows.Forms.Label
    $messageLabel.Text = 'What do you want to say?'
    $messageLabel.Location = New-Object System.Drawing.Point(16, 78)
    $messageLabel.AutoSize = $true
    $form.Controls.Add($messageLabel)

    $messageBox = New-Object System.Windows.Forms.TextBox
    $messageBox.Location = New-Object System.Drawing.Point(16, 102)
    $messageBox.Size = New-Object System.Drawing.Size(570, 220)
    $messageBox.Multiline = $true
    $messageBox.ScrollBars = 'Vertical'
    $messageBox.AcceptsReturn = $true
    $form.Controls.Add($messageBox)

    $sendButton = New-Object System.Windows.Forms.Button
    $sendButton.Text = 'Send'
    $sendButton.Location = New-Object System.Drawing.Point(390, 340)
    $sendButton.Size = New-Object System.Drawing.Size(90, 32)
    $sendButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $sendButton
    $form.Controls.Add($sendButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Location = New-Object System.Drawing.Point(496, 340)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 32)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $form.Add_Shown({ $messageBox.Focus() })
    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-InteractionLog 'Interaction cancelled.'
        exit 0
    }

    $playerMessage = $messageBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($playerMessage)) {
        Show-ErrorMessage 'Enter a message before sending it.'
        exit 2
    }

    $npcName = $npcBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($npcName)) {
        $npcName = 'the NPC currently speaking to the player'
    }

    $token = '{0}_{1}' -f ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()), ([Guid]::NewGuid().ToString('N'))
    $requestPath = Join-Path $requests ($token + '.request')
    $responsePath = Join-Path $responses ($token + '.response')

    $requestText = @"
NPC=$npcName
MODEL=gpt-5.4-mini
MAX_OUTPUT_TOKENS=220
---MESSAGE---
$playerMessage
"@

    [System.IO.File]::WriteAllText($requestPath, $requestText, (New-Object System.Text.UTF8Encoding($false)))
    Write-InteractionLog "Sending request $token for NPC '$npcName'."

    $process = Start-Process -FilePath $bridge -ArgumentList @('--request', $requestPath, '--response', $responsePath) -Wait -PassThru -WindowStyle Hidden
    if (-not (Test-Path -LiteralPath $responsePath -PathType Leaf)) {
        throw "The bridge exited with code $($process.ExitCode) without creating a response file."
    }

    $reply = [System.IO.File]::ReadAllText($responsePath).Trim()
    Remove-Item -LiteralPath $responsePath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($reply)) {
        throw 'The bridge returned an empty response.'
    }

    Write-InteractionLog "Request $token completed with exit code $($process.ExitCode)."

    $replyForm = New-Object System.Windows.Forms.Form
    $replyForm.Text = "AI Dialogue - $npcName"
    $replyForm.StartPosition = 'CenterScreen'
    $replyForm.Size = New-Object System.Drawing.Size(650, 430)
    $replyForm.MinimumSize = New-Object System.Drawing.Size(650, 430)
    $replyForm.TopMost = $true

    $replyBox = New-Object System.Windows.Forms.TextBox
    $replyBox.Location = New-Object System.Drawing.Point(16, 16)
    $replyBox.Size = New-Object System.Drawing.Size(600, 320)
    $replyBox.Multiline = $true
    $replyBox.ReadOnly = $true
    $replyBox.ScrollBars = 'Vertical'
    $replyBox.Text = $reply
    $replyForm.Controls.Add($replyBox)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Close'
    $closeButton.Location = New-Object System.Drawing.Point(526, 350)
    $closeButton.Size = New-Object System.Drawing.Size(90, 32)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $replyForm.AcceptButton = $closeButton
    $replyForm.Controls.Add($closeButton)

    $replyForm.ShowDialog() | Out-Null
    exit 0
}
catch {
    Show-ErrorMessage $_.Exception.Message
    exit 1
}
