<#
  install.ps1 - installs KairoFrame for Windows (64-bit) and what it needs to render, all in one folder:

    %LOCALAPPDATA%\KairoFrame\bin\          kairoframe.exe and its DLLs (from this repository's GitHub release)
                                            chrome-headless-shell (Chrome for Testing), next to kairoframe.exe
    %LOCALAPPDATA%\KairoFrame\bin\ffmpeg\   ffmpeg.exe / ffprobe.exe (FFmpeg 8.1, BtbN/FFmpeg-Builds)

  and puts %LOCALAPPDATA%\KairoFrame\bin on the user's PATH. Running it again updates KairoFrame and keeps the rest.

    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 [-Version v0.1.0] [-Dir C:\path] [-NoPath]
#>
param(
  [string]$Version = "latest",
  [string]$Dir = (Join-Path $env:LOCALAPPDATA "KairoFrame"),
  [switch]$NoPath
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"          # Invoke-WebRequest is many times slower with its progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = "aisnote/kairoframe"
$ChromeVersion = "152.0.7977.30"
$FfmpegZip = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-win64-gpl-8.1.zip"

if (-not [Environment]::Is64BitOperatingSystem) { throw "KairoFrame needs 64-bit Windows." }
$bin = Join-Path $Dir "bin"
$tmp = Join-Path $env:TEMP ("kairoframe-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $bin, $tmp | Out-Null

function Get-File([string]$Url, [string]$Out) {
  Write-Host "  downloading $Url"
  for ($i = 1; $i -le 3; $i++) {
    try { Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing -Headers @{ "User-Agent" = "kairoframe-install" }; return }
    catch { if ($i -eq 3) { throw }; Start-Sleep -Seconds (2 * $i) }
  }
}

try {
  # 1. KairoFrame
  $api = "https://api.github.com/repos/$Repo/releases/" + $(if ($Version -eq "latest") { "latest" } else { "tags/$Version" })
  $rel = Invoke-RestMethod -UseBasicParsing -Uri $api -Headers @{ "User-Agent" = "kairoframe-install" }
  $asset = $rel.assets | Where-Object { $_.name -like "kairoframe-win64-*.zip" } | Select-Object -First 1
  if (-not $asset) { throw "release $($rel.tag_name) has no kairoframe-win64 zip" }
  Write-Host "KairoFrame $($rel.tag_name)"
  $zip = Join-Path $tmp $asset.name
  Get-File $asset.browser_download_url $zip
  Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp "kf") -Force
  $src = Get-ChildItem -Path (Join-Path $tmp "kf") -Recurse -Filter "kairoframe.exe" | Select-Object -First 1
  Copy-Item -Path (Join-Path $src.DirectoryName "*") -Destination $bin -Recurse -Force
  Set-Content -Path (Join-Path $Dir "VERSION") -Value $rel.tag_name -Encoding ascii

  # 2. ffmpeg.exe and ffprobe.exe in bin\ffmpeg\ (looked in first)
  $ff = Join-Path $bin "ffmpeg"
  if (-not (Test-Path (Join-Path $ff "ffmpeg.exe"))) {
    Write-Host "ffmpeg 8.1"
    $zip = Join-Path $tmp "ffmpeg.zip"
    Get-File $FfmpegZip $zip
    Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp "ffmpeg") -Force
    $exe = Get-ChildItem -Path (Join-Path $tmp "ffmpeg") -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $ff | Out-Null
    Copy-Item (Join-Path $exe.DirectoryName "ffmpeg.exe"), (Join-Path $exe.DirectoryName "ffprobe.exe") -Destination $ff -Force
    $lic = Get-ChildItem -Path (Join-Path $tmp "ffmpeg") -Recurse -Filter "LICENSE.txt" | Select-Object -First 1
    if ($lic) { Copy-Item $lic.FullName (Join-Path $ff "LICENSE.txt") -Force }
  } else { Write-Host "ffmpeg: already there" }

  # 3. the headless browser, next to kairoframe.exe (looked in there)
  $stamp = Join-Path $bin "chrome-headless-shell.version"
  $have = if (Test-Path $stamp) { (Get-Content $stamp -Raw).Trim() } else { "" }
  if (-not (Test-Path (Join-Path $bin "chrome-headless-shell.exe")) -or $have -ne $ChromeVersion) {
    Write-Host "chrome-headless-shell $ChromeVersion"
    $zip = Join-Path $tmp "chrome.zip"
    Get-File "https://storage.googleapis.com/chrome-for-testing-public/$ChromeVersion/win64/chrome-headless-shell-win64.zip" $zip
    Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp "chrome") -Force
    Copy-Item -Path (Join-Path $tmp "chrome\chrome-headless-shell-win64\*") -Destination $bin -Recurse -Force
    Set-Content -Path $stamp -Value $ChromeVersion -Encoding ascii
  } else { Write-Host "chrome-headless-shell: already there" }

  # 4. PATH
  if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { $userPath = "" }
    if (($userPath -split ";") -notcontains $bin) {
      [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $bin).TrimStart(";"), "User")
      Write-Host "added $bin to the user PATH (new terminals see it)"
    }
    if (($env:Path -split ";") -notcontains $bin) { $env:Path = "$env:Path;$bin" }
  }

  Write-Host ""
  & (Join-Path $bin "kairoframe.exe") doctor
  Write-Host ""
  Write-Host "KairoFrame is installed: $(Join-Path $bin 'kairoframe.exe')"
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
