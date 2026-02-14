$ErrorActionPreference = "SilentlyContinue"
$backendDir = $PSScriptRoot
$backendPathPattern = [Regex]::Escape($backendDir)

$procs = Get-CimInstance Win32_Process |
  Where-Object {
    $_.Name -match "python" -and
    $_.CommandLine -match "server\.py" -and
    $_.CommandLine -match $backendPathPattern
  }

foreach ($proc in $procs) {
  Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}
