param(
    [string]$DistArch = "amd64"
)

$ErrorActionPreference = "Stop"

$versionLine = Select-String -Path Cargo.toml -Pattern '^version = "([^"]+)"'
$version = $versionLine.Matches[0].Groups[1].Value
$dist = "output\windows\clash-gatito-$version-windows-$DistArch"

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item target\release\clash-gatito.exe "$dist\Clash Gatito.exe"
Copy-Item tray_icon.png "$dist\tray_icon.png"
Copy-Item app_icon.png "$dist\app_icon.png"
Copy-Item LICENSE "$dist\LICENSE"
Copy-Item README.md "$dist\README.md"
Compress-Archive -Path "$dist\*" -DestinationPath "$dist.zip" -Force
