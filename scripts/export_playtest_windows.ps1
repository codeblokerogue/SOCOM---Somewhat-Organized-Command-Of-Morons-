param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $GodotPath)) {
    Write-Error "Godot binary not found at: $GodotPath"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..")
$outputDir = Join-Path $projectRoot "builds/playtest"
$outputPath = Join-Path $outputDir "SOCOM_Playtest.exe"

if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

& $GodotPath --headless --path $projectRoot --export-release "Windows Desktop" $outputPath
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "Export failed with exit code $exitCode"
    exit $exitCode
}

Write-Host "Playtest build exported to: $outputPath"
