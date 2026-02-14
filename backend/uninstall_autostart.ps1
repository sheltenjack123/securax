$ErrorActionPreference = "SilentlyContinue"

$taskName = "SecuraxBackendAutostart"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

try {
  $startupFolder = [Environment]::GetFolderPath("Startup")
  $launcherPath = Join-Path $startupFolder "SecuraxBackendAutostart.cmd"
  if (Test-Path $launcherPath) {
    Remove-Item -Path $launcherPath -Force
  }
} catch {}

Write-Output "Removed task: $taskName"
