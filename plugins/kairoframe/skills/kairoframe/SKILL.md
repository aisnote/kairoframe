---
name: kairoframe
description: Make, edit, check and render videos from HTML with KairoFrame (HTML + CSS + a paused GSAP timeline, rendered to MP4, MOV, WebM, GIF, PNG frames or HLS), and render existing Hyperframes projects several times faster. Use when the user asks to create a video, motion graphic, animated title, lower third, product promo, social clip or slideshow, to turn a web page or HTML into a video, to recreate or recompose a video as HTML, or to render a Hyperframes project. Windows 64-bit.
---

# KairoFrame: HTML to video

KairoFrame renders a folder holding an `index.html` (the Hyperframes project format: plain HTML timed by `data-`
attributes and animated by a paused GSAP timeline) to a video file. It is a single native program; a Hyperframes project
renders as it is.

**Command name:** always run it as `kairoframe`. Text the program prints (its help, `docs`, check findings, hints) and
the files `kairoframe init` writes may show the command under the engine's internal name: read every such command as
`kairoframe`.

## 1. Make sure KairoFrame is installed

Run `kairoframe doctor`. If the command is not found, try `%LOCALAPPDATA%\KairoFrame\bin\kairoframe.exe doctor`
(in Git Bash `"$LOCALAPPDATA/KairoFrame/bin/kairoframe.exe" doctor`). If neither exists, install it with the script
next to this file. It downloads KairoFrame, ffmpeg and a headless Chrome (about 250 MB) into
`%LOCALAPPDATA%\KairoFrame` and adds it to the user's PATH:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<this skill's folder>\scripts\install.ps1"
```

Until a new terminal picks up the PATH, call it by its full path. `doctor` must print `ok` for the browser before
rendering. Running the script again updates KairoFrame.

## 2. Start or open a project

- New project: `kairoframe init <folder>` writes `index.html` (a 1920x1080, 6 s starter) and notes for agents. Read them,
  then run `kairoframe docs` for the full format reference (layout, clips, video and audio, captions, compositions in
  files, variables, colour grading, transitions).
- Existing Hyperframes project: work in its folder as it is; no conversion is needed.

## 3. The format, the rules that matter most

- The root element has `data-composition-id`, `data-width`, `data-height`, `data-duration` (and optionally `data-fps`).
- An element with `data-start` and `data-duration` (seconds) is shown only during that time.
- All motion goes into one GSAP timeline created with `{ paused: true }` and registered as
  `window.__timelines["<composition id>"] = tl`. Positions in the timeline are seconds of film time.
- A frame must depend only on its time: no `Math.random()`, `Date.now()`, `setTimeout`, `requestAnimationFrame`,
  `repeat: -1` or `play()`. Frames are drawn out of order.
- `<video>` and `<audio>` need `src` and `data-start` (plus `data-duration`, `data-media-start` to trim). Put media,
  pictures and fonts in `assets/` and refer to them with relative paths.
- Fonts: name families in CSS (`font-family: Inter, sans-serif`); Google Fonts families are fetched automatically.
- Layer order is CSS `z-index`. Keep text 24 px or larger (at 1080 lines) and 5% away from the edges.

## 4. The loop: edit, check, look, render

1. Edit `index.html`.
2. `kairoframe check --json`: fix every finding with `"severity": "error"`, read every warning.
3. `kairoframe sheet -o sheet.jpg` and look at the picture (Read the file): check cannot judge line breaks, colours or
   balance. `kairoframe sheet --at 1.0,2.5,4.0` shows chosen moments, `kairoframe frame --at 3.2 -o f.png` one frame.
4. `kairoframe render -o out.mp4 --json` (use `--quality draft` while iterating). Report the `output` path and
   `seconds.total` from the JSON.

Useful render options: `--quality draft|standard|high`, `--fps N`, `--start S --end S`,
`--format mp4|mov|webm|gif|png-sequence|hls`, `--transparent` (mov, webm, png-sequence), `--encoder auto|cpu|gpu` (auto
uses the graphics card's H.264 encoder when there is one), `--variables '{"title":"..."}'` for one project rendered with
different values. `kairoframe render --help` lists all.

Every command takes `--json` (one JSON document on stdout). Exit codes: 0 done, 1 failed, 2 wrong usage, 3 check or lint
found errors. A failure is `{"ok": false, "error": {"code", "message", "hint"}}`: follow the hint.

## 5. Recreating an existing video as HTML

Download the source (for a post on X, `https://api.fxtwitter.com/<user>/status/<id>` gives the video URLs), take a contact
sheet with ffmpeg (`ffmpeg -i in.mp4 -vf "fps=2,scale=240:-1,tile=8x5" sheet.png`, the ffmpeg in KairoFrame's
`bin\ffmpeg` folder works) and read it to list the shots and their times, then rebuild each shot as HTML with the
timeline. Footage that cannot be drawn in HTML (gameplay, camera shots) can be cut from the source with ffmpeg into
`assets/` and placed as `<video>` clips. Compare your render with the source side by side
(`ffmpeg -i a.mp4 -i b.mp4 -filter_complex hstack side.mp4`) and adjust the timing. Only reuse material the user has the
right to use.

## Troubleshooting

- `doctor` reports no browser, or ffmpeg is not found: run the install script again.
- A blank or frozen frame: something depends on real time (see the rules above), or an asset path is wrong
  (`kairoframe lint`).
