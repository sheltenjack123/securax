$ErrorActionPreference = "Stop"

$taskName = "SecuraxBackendAutostart"
$scriptPath = Join-Path $PSScriptRoot "start_backend.ps1"
$powershellExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"

if (!(Test-Path $scriptPath)) {
  throw "Missing script: $scriptPath"
}

function Install-ScheduledTask {
  $principalUser = "$env:USERDOMAIN\$env:USERNAME"
  $action = New-ScheduledTaskAction `
    -Execute $powershellExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)

  $principal = New-ScheduledTaskPrincipal `
    -UserId $principalUser `
    -LogonType Interactive `
    -RunLevel Limited

  $task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal

  Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
  Start-ScheduledTask -TaskName $taskName
  Write-Output "Installed and started scheduled task: $taskName"
}

function Install-StartupFolderLauncher {
  $startupFolder = [Environment]::GetFolderPath("Startup")
  $launcherPath = Join-Path $startupFolder "SecuraxBackendAutostart.cmd"
  $launcher = "@echo off`r`n`"$powershellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"`r`n"
  Set-Content -Path $launcherPath -Value $launcher -Encoding ASCII
  & $powershellExe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptPath
  Write-Output "Installed Startup-folder launcher: $launcherPath"
}

try {
  Install-ScheduledTask
} catch {
  Install-StartupFolderLauncher
}
