param(
  [string]$ProjectDir = (Join-Path $PSScriptRoot ".."),
  [string]$OutZip = (Join-Path $PSScriptRoot "..\SmartAgroConnect-src.zip")
)

$resolved = Resolve-Path $ProjectDir
Write-Host "Zipping $resolved -> $OutZip"
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }
Compress-Archive -Path (Join-Path $resolved "*") -DestinationPath $OutZip -Force
Write-Host "Done."
