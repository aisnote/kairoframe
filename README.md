# KairoFrame for Claude Code

**Website and demo video: https://aisnote.github.io/kairoframe/**

KairoFrame is a fast, native video renderer. It turns

- **HTML projects**: a folder with an `index.html` (plain HTML and CSS, timed by `data-` attributes, animated by a
  paused GSAP timeline, the [Hyperframes](https://github.com/heygen-com/hyperframes) project format), with the video
  clips, pictures and **sound** they place: music, voice-over, sound effects, with volume curves, speed changes and a
  chain of audio effects (EQ, compressor, limiter, reverb, delay, ...);
- **any web page or built site** (React, Vue, plain HTML), recorded frame by frame on a virtual clock;
- **video clips and pictures**, stacked in layers and joined segment after segment (`kairoframe compose`)

into **MP4, MOV (ProRes), WebM, GIF, PNG frames or HLS**, optionally in HDR (HDR10 or HLG) and with the graphics card's
H.264 encoder. It is a single program, typically about 5x faster than Hyperframes on the same project. This repository
holds the Claude Code plugin and the Windows and Linux binaries; the source code is not published.

**Platforms:** Windows 10/11 64-bit; Linux x86-64 (glibc 2.38 or newer: Ubuntu 24.04, Debian 13, Fedora 39 or later; a CPU
with AVX2).

## Install for every agent: one line

Windows 10/11, in a terminal (cmd, PowerShell or Git Bash):

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/aisnote/kairoframe/main/install.ps1 | iex"
```

Linux (x86-64), in a terminal:

```
curl -fsSL https://raw.githubusercontent.com/aisnote/kairoframe/main/install.sh | bash
```

It installs KairoFrame, ffmpeg and a headless Chrome (about 250 MB) into `%LOCALAPPDATA%\KairoFrame` on Windows or
`~/.local/share/kairoframe` on Linux, puts `kairoframe` on your PATH (on Linux as a link in `~/.local/bin`), and gives the
KairoFrame skill to the coding agents on the machine:

| Agent | What it gets |
|---|---|
| Claude Code | the skill in `~/.claude/skills/kairoframe` (`%USERPROFILE%\.claude\skills\kairoframe`) |
| OpenAI Codex CLI | the skill in `~/.codex/skills/kairoframe` and a section in `~/.codex/AGENTS.md` |
| Gemini CLI | a section in `~/.gemini/GEMINI.md` |
| any other agent | point it at `%LOCALAPPDATA%\KairoFrame\SKILL.md` or `~/.local/share/kairoframe/SKILL.md` |

On a Linux machine without a desktop, the installer lists the system libraries the headless browser still needs and the
`apt-get` / `dnf` command that installs them.

Codex and Gemini are set up only when they are installed (their folder exists). Run the same line again to update.
Then open your agent and ask for a video.

## Use it in Claude Code

```
/plugin marketplace add aisnote/kairoframe
/plugin install kairoframe@kairoframe
/kairoframe:install
```

(the plugin way, for Claude Code only.) `/kairoframe:install` downloads KairoFrame, ffmpeg and a headless Chrome (about 250 MB in all) into
`%LOCALAPPDATA%\KairoFrame` (Windows) or `~/.local/share/kairoframe` (Linux) and puts it on your PATH. Then ask Claude for a video, for example: *"Make a 10-second
1080x1080 product teaser for my app with three feature cards"*, or *"Render this Hyperframes project with KairoFrame"*.
The plugin's skill tells Claude how to write the project, check it, look at it and render it.

## Install by hand

Download `kairoframe-win64-<version>.zip` (Windows) or `kairoframe-linux-x64-<version>.tar.gz` (Linux) from
[Releases](https://github.com/aisnote/kairoframe/releases) and unpack it. Put `ffmpeg` and `ffprobe` (6.0 or newer) in an
`ffmpeg` folder next to the `kairoframe` program and
[chrome-headless-shell](https://googlechromelabs.github.io/chrome-for-testing/) next to it (on Linux its
`chrome-headless-shell-linux64` folder), then run `kairoframe doctor`. On Linux, `install.sh --from <the .tar.gz>` does
the rest for a package you downloaded.

On Windows everything goes into `%LOCALAPPDATA%\KairoFrame\bin`: `kairoframe.exe` and its DLLs, chrome-headless-shell (Chrome for
Testing 152), and `ffmpeg\` (FFmpeg 8.1, [BtbN builds](https://github.com/BtbN/FFmpeg-Builds)). On Linux the same goes into
`~/.local/share/kairoframe/bin` (`kairoframe`, `lib/`, `chrome-headless-shell-linux64/`, `ffmpeg/`). Fonts used by projects
are fetched from Google Fonts on first use and kept in a cache in your user folder.

## Quick start

```
kairoframe init my-video          # index.html and notes for agents
cd my-video
kairoframe check --json           # finds layout and timing problems
kairoframe sheet -o sheet.jpg     # one picture of the whole film
kairoframe render -o out.mp4      # the video
kairoframe docs                   # the full format reference
```

## License

The binaries are free to use; see `LICENSE.txt` in the release zip. Third-party components keep their own licenses
(`THIRD_PARTY_NOTICES.txt`): FFmpeg's libraries and FriBidi are LGPL shared libraries (DLLs on Windows, `lib/*.so` on
Linux) you may replace. The scripts and documents in
this repository are MIT licensed.
