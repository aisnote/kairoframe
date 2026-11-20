#!/usr/bin/env bash
# KairoFrame installer for Linux (x86-64): the program, and the skill for the coding agents on this machine.
#
#   One line:
#     curl -fsSL https://raw.githubusercontent.com/aisnote/kairoframe/main/install.sh | bash
#
# Installs into ~/.local/share/kairoframe/bin (kairoframe and its lib/, chrome-headless-shell, ffmpeg/), links
# ~/.local/bin/kairoframe to it, and registers the KairoFrame skill with:
#   Claude Code   ~/.claude/skills/kairoframe/SKILL.md
#   Codex CLI     ~/.codex/skills/kairoframe/SKILL.md and a section in ~/.codex/AGENTS.md
#   Gemini CLI    a section in ~/.gemini/GEMINI.md
# (Codex and Gemini only when their folder exists.) Running it again updates everything in place.
#
# Options (curl ... | bash -s -- <options>): --version <tag>, --dir <folder>, --no-path, --no-agents,
# --from <kairoframe-linux-x64-*.tar.gz> (install a downloaded package instead of the latest release).
set -euo pipefail

REPO="aisnote/kairoframe"
RAW="https://raw.githubusercontent.com/$REPO/main"
CHROME_VERSION="152.0.7977.30"
FFMPEG_TAR="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-linux64-gpl-8.1.tar.xz"
UA="kairoframe-install"

VERSION="latest"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kairoframe"
NO_PATH=0
NO_AGENTS=0
FROM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --no-path) NO_PATH=1; shift ;;
    --no-agents) NO_AGENTS=1; shift ;;
    --from) FROM="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "kairoframe install: $*" >&2; exit 1; }

# ---- what this machine needs
[ "$(uname -s)" = Linux ] || die "this installer is for Linux; on Windows use install.ps1"
[ "$(uname -m)" = x86_64 ] || die "KairoFrame for Linux is built for x86-64 (this machine is $(uname -m))"
grep -q -w avx2 /proc/cpuinfo || die "KairoFrame needs a CPU with AVX2 (Intel Haswell / AMD Excavator, 2013 or later)"
glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
if [ -n "$glibc" ] && [ "$(printf '%s\n2.38\n' "$glibc" | sort -V | head -1)" != 2.38 ]; then
  die "KairoFrame needs glibc 2.38 or newer (Ubuntu 24.04, Debian 13, Fedora 39 or later); this system has $glibc"
fi
for t in curl tar xz; do command -v "$t" > /dev/null || die "needs '$t' (install it with your package manager)"; done
unzip_to() {   # unzip_to <zip> <folder>
  if command -v unzip > /dev/null; then unzip -q -o "$1" -d "$2"
  elif command -v python3 > /dev/null; then python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$1" "$2"
  else die "needs 'unzip' (or python3) to unpack the headless browser"; fi
}
get() {   # get <url> <file>
  echo "  downloading $1"
  curl -fL --retry 3 --retry-delay 2 -sS -A "$UA" -o "$2" "$1"
}

BIN="$DIR/bin"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/kairoframe-install-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN"

# ---- 1. KairoFrame
if [ -n "$FROM" ]; then
  [ -f "$FROM" ] || die "no such file: $FROM"
  TAG="$(basename "$FROM" | sed -n 's/^kairoframe-linux-x64-\(.*\)\.tar\.gz$/\1/p')"
  cp "$FROM" "$TMP/kf.tar.gz"
else
  if [ "$VERSION" = latest ]; then api="https://api.github.com/repos/$REPO/releases?per_page=30"
  else api="https://api.github.com/repos/$REPO/releases/tags/$VERSION"; fi
  # the newest release that has a Linux package (releases are listed newest first)
  url="$(curl -fsSL -A "$UA" "$api" | grep -o '"browser_download_url": *"[^"]*kairoframe-linux-x64-[^"]*\.tar\.gz"' | head -1 | sed 's/.*"\(https[^"]*\)"$/\1/')"
  [ -n "$url" ] || die "no Linux package found in the releases of $REPO${VERSION:+ ($VERSION)}"
  TAG="$(basename "$url" | sed -n 's/^kairoframe-linux-x64-\(.*\)\.tar\.gz$/\1/p')"
  get "$url" "$TMP/kf.tar.gz"
fi
echo "KairoFrame ${TAG:-(local package)}"
mkdir -p "$TMP/kf"
tar -xzf "$TMP/kf.tar.gz" -C "$TMP/kf"
src="$(dirname "$(find "$TMP/kf" -type f -name kairoframe -perm -u+x | head -1)")"
[ -x "$src/kairoframe" ] || die "the package holds no kairoframe program"
rm -rf "$BIN/lib" "$BIN/licenses"
cp -a "$src/." "$BIN/"
echo "${TAG:-local}" > "$DIR/VERSION"

# ---- 2. ffmpeg and ffprobe in bin/ffmpeg/ (looked in first)
FF="$BIN/ffmpeg"
if [ ! -x "$FF/ffmpeg" ]; then
  echo "ffmpeg 8.1"
  get "$FFMPEG_TAR" "$TMP/ffmpeg.tar.xz"
  mkdir -p "$TMP/ffmpeg" "$FF"
  tar -xJf "$TMP/ffmpeg.tar.xz" -C "$TMP/ffmpeg"
  fb="$(dirname "$(find "$TMP/ffmpeg" -type f -name ffmpeg -perm -u+x | head -1)")"
  cp "$fb/ffmpeg" "$fb/ffprobe" "$FF/"
  lic="$(find "$TMP/ffmpeg" -name LICENSE.txt | head -1)"
  [ -n "$lic" ] && cp "$lic" "$FF/LICENSE.txt"
else echo "ffmpeg: already there"; fi

# ---- 3. the headless browser, next to kairoframe (looked in there)
stamp="$BIN/chrome-headless-shell.version"
have="$(cat "$stamp" 2>/dev/null || true)"
if [ ! -x "$BIN/chrome-headless-shell-linux64/chrome-headless-shell" ] || [ "$have" != "$CHROME_VERSION" ]; then
  echo "chrome-headless-shell $CHROME_VERSION"
  get "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chrome-headless-shell-linux64.zip" "$TMP/chrome.zip"
  rm -rf "$BIN/chrome-headless-shell-linux64"
  unzip_to "$TMP/chrome.zip" "$BIN"
  chmod +x "$BIN/chrome-headless-shell-linux64/chrome-headless-shell"
  echo "$CHROME_VERSION" > "$stamp"
else echo "chrome-headless-shell: already there"; fi
missing="$(ldd "$BIN/chrome-headless-shell-linux64/chrome-headless-shell" 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ')"
if [ -n "$missing" ]; then
  echo "the headless browser needs system libraries that are not installed: $missing"
  echo "  Debian / Ubuntu: sudo apt-get install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \\"
  echo "                   libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2t64"
  echo "  Fedora:          sudo dnf install -y nss atk at-spi2-atk cups-libs libdrm libxkbcommon libXcomposite libXdamage \\"
  echo "                   libXrandr mesa-libgbm pango cairo alsa-lib"
fi

# ---- 4. PATH: a link in ~/.local/bin
if [ "$NO_PATH" = 0 ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$BIN/kairoframe" "$HOME/.local/bin/kairoframe"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      line='export PATH="$HOME/.local/bin:$PATH"   # kairoframe'
      for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -q '# kairoframe$' "$rc" && printf '\n%s\n' "$line" >> "$rc" && echo "added ~/.local/bin to PATH in $rc (new terminals see it)"
      done ;;
  esac
fi

# ---- 5. the skill, for the coding agents on this machine
set_block() {   # set_block <file> <text>: the text between markers, replaced when there, added at the end when not
  local file="$1" body="$2" start="<!-- kairoframe:start -->" end="<!-- kairoframe:end -->"
  mkdir -p "$(dirname "$file")"; touch "$file"
  python3 - "$file" "$start" "$end" "$body" 2> /dev/null <<'PY' || { grep -q "$start" "$file" || printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >> "$file"; }
import sys
f, s, e, body = sys.argv[1:]
t = open(f, encoding="utf-8").read()
block = s + "\n" + body + "\n" + e
i, j = t.find(s), t.find(e)
t = t[:i] + block + t[j + len(e):] if i >= 0 and j > i else (t.rstrip() + "\n\n" + block + "\n").lstrip()
open(f, "w", encoding="utf-8").write(t)
PY
}
if [ "$NO_AGENTS" = 0 ]; then
  echo "agents"
  SKILL="$DIR/SKILL.md"
  get "$RAW/plugins/kairoframe/skills/kairoframe/SKILL.md" "$SKILL"
  get "$RAW/install.sh" "$DIR/install.sh"
  get "$RAW/install.ps1" "$DIR/install.ps1"
  for root in "$HOME/.claude" "$HOME/.codex"; do
    [ "$root" = "$HOME/.claude" ] || [ -d "$root" ] || continue
    d="$root/skills/kairoframe"
    mkdir -p "$d/scripts"
    cp "$SKILL" "$d/SKILL.md"
    cp "$DIR/install.sh" "$DIR/install.ps1" "$d/scripts/"
    echo "  $( [ "$root" = "$HOME/.claude" ] && echo "Claude Code" || echo "Codex CLI" ): skill in $d"
  done
  note="## KairoFrame (HTML to video)

When asked to make, edit, check or render a video, motion graphic, animated title, lower third or promo from HTML, or to
render a Hyperframes project, use KairoFrame (\`kairoframe\`, installed in \`$BIN\`). Read \`$SKILL\` first: it has the
project format and the edit, check, sheet, render loop."
  [ -d "$HOME/.codex" ] && set_block "$HOME/.codex/AGENTS.md" "$note" && echo "  Codex CLI: section in ~/.codex/AGENTS.md"
  [ -d "$HOME/.gemini" ] && set_block "$HOME/.gemini/GEMINI.md" "$note" && echo "  Gemini CLI: section in ~/.gemini/GEMINI.md"
  echo "  any other agent: point it at $SKILL"
fi

echo
"$BIN/kairoframe" doctor || true
echo
echo "KairoFrame is installed: $BIN/kairoframe"
