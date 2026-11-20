<#
  KairoFrame installer for Windows (64-bit): the program, and the skill for the coding agents on this machine.

  One line (cmd, PowerShell or Git Bash):
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/aisnote/kairoframe/main/install.ps1 | iex"

  Installs into %LOCALAPPDATA%\KairoFrame\bin (kairoframe.exe and its DLLs, chrome-headless-shell, ffmpeg\), adds it to
  the user's PATH, and registers the KairoFrame skill with:
    Claude Code   %USERPROFILE%\.claude\skills\kairoframe\SKILL.md
    Codex CLI     %USERPROFILE%\.codex\skills\kairoframe\SKILL.md and a section in %USERPROFILE%\.codex\AGENTS.md
    Gemini CLI    a section in %USERPROFILE%\.gemini\GEMINI.md
  (Codex and Gemini only when their folder exists.) Running it again updates everything in place.

  Options, when the script is saved and run with -File: -Version v0.1.0, -Dir <folder>, -NoPath, -NoAgents.
#>
param(
  [string]$Version = "latest",
  [string]$Dir = (Join-Path $env:LOCALAPPDATA "KairoFrame"),
  [switch]$NoPath,
  [switch]$NoAgents
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"          # Invoke-WebRequest is many times slower with its progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = "aisnote/kairoframe"
$Raw = "https://raw.githubusercontent.com/$Repo/main"
$ChromeVersion = "152.0.7977.30"
$FfmpegZip = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-win64-gpl-8.1.zip"
$UA = @{ "User-Agent" = "kairoframe-install" }

if (-not [Environment]::Is64BitOperatingSystem) { throw "KairoFrame needs 64-bit Windows." }
$bin = Join-Path $Dir "bin"
$tmp = Join-Path $env:TEMP ("kairoframe-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $bin, $tmp | Out-Null

function Get-File([string]$Url, [string]$Out) {
  Write-Host "  downloading $Url"
  for ($i = 1; $i -le 3; $i++) {
    try { Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing -Headers $UA; return }
    catch { if ($i -eq 3) { throw }; Start-Sleep -Seconds (2 * $i) }
  }
}

# a block of text between markers in a file: replaced when it is there, added at the end when not
function Set-Block([string]$File, [string]$Body) {
  $start = "<!-- kairoframe:start -->"; $end = "<!-- kairoframe:end -->"
  $block = "$start`r`n$Body`r`n$end"
  $text = if (Test-Path $File) { [IO.File]::ReadAllText($File) } else { "" }
  $i = $text.IndexOf($start); $j = $text.IndexOf($end)
  if ($i -ge 0 -and $j -gt $i) { $text = $text.Substring(0, $i) + $block + $text.Substring($j + $end.Length) }
  else { $text = ($text.TrimEnd() + "`r`n`r`n" + $block + "`r`n").TrimStart() }
  [IO.File]::WriteAllText($File, $text, (New-Object Text.UTF8Encoding $false))
}

try {
  # 1. KairoFrame
  $api = "https://api.github.com/repos/$Repo/releases/" + $(if ($Version -eq "latest") { "latest" } else { "tags/$Version" })
  $rel = Invoke-RestMethod -UseBasicParsing -Uri $api -Headers $UA
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

  # 5. the skill, for the coding agents on this machine
  if (-not $NoAgents) {
    Write-Host "agents"
    $skill = Join-Path $Dir "SKILL.md"
    Get-File "$Raw/plugins/kairoframe/skills/kairoframe/SKILL.md" $skill
    $installer = Join-Path $Dir "install.ps1"
    Get-File "$Raw/install.ps1" $installer
    $places = @(@{ Name = "Claude Code"; Root = (Join-Path $env:USERPROFILE ".claude"); Always = $true },
                @{ Name = "Codex CLI"; Root = (Join-Path $env:USERPROFILE ".codex"); Always = $false })
    foreach ($p in $places) {
      if (-not $p.Always -and -not (Test-Path $p.Root)) { continue }
      $d = Join-Path $p.Root "skills\kairoframe"
      New-Item -ItemType Directory -Force -Path (Join-Path $d "scripts") | Out-Null
      Copy-Item $skill (Join-Path $d "SKILL.md") -Force
      Copy-Item $installer (Join-Path $d "scripts\install.ps1") -Force
      Write-Host "  $($p.Name): skill in $d"
    }
    $note = @"
## KairoFrame (HTML to video)

When asked to make, edit, check or render a video, motion graphic, animated title, lower third or promo from HTML, or to
render a Hyperframes project, use KairoFrame (``kairoframe``, installed in ``$bin``). Read ``$skill`` first: it has the
project format and the edit, check, sheet, render loop.
"@
    $codex = Join-Path $env:USERPROFILE ".codex"
    if (Test-Path $codex) { Set-Block (Join-Path $codex "AGENTS.md") $note; Write-Host "  Codex CLI: section in $codex\AGENTS.md" }
    $gemini = Join-Path $env:USERPROFILE ".gemini"
    if (Test-Path $gemini) { Set-Block (Join-Path $gemini "GEMINI.md") $note; Write-Host "  Gemini CLI: section in $gemini\GEMINI.md" }
    Write-Host "  any other agent: point it at $skill"
  }

  Write-Host ""
  & (Join-Path $bin "kairoframe.exe") doctor
  Write-Host ""
  Write-Host "KairoFrame is installed: $(Join-Path $bin 'kairoframe.exe')"
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
