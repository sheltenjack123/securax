param(
  [int]$Port = 5000
)

$ErrorActionPreference = "Stop"
$backendDir = $PSScriptRoot
$logDir = Join-Path $backendDir "logs"
$logFile = Join-Path $logDir "backend.log"

if (!(Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}

$isListening = netstat -ano | Select-String ":$Port\s+.*LISTENING"
if ($isListening) {
  exit 0
}

$venvPython = Join-Path $backendDir ".venv\Scripts\python.exe"
if (Test-Path $venvPython) {
  Start-Process -FilePath $venvPython `
    -ArgumentList "server.py" `
    -WorkingDirectory $backendDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $logFile
  exit 0
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  Start-Process -FilePath "py" `
    -ArgumentList "-3 server.py" `
    -WorkingDirectory $backendDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $logFile
  exit 0
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  Start-Process -FilePath "python" `
    -ArgumentList "server.py" `
    -WorkingDirectory $backendDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $logFile
  exit 0
}

throw "Python runtime not found. Install Python or create backend/.venv."
