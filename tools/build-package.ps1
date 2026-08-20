param([string]$Version = '0.1.3')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
$source = Join-Path $root 'apps'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist "MulticlassRelative-v$Version.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# Keep the `apps` directory itself: Content Manager packages are extracted at
# the Assetto Corsa root and therefore need apps/lua/MulticlassRelative.
Compress-Archive -Path $source -DestinationPath $zip -Force
Write-Output $zip
