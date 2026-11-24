---
name: kairoframe
description: Make, edit, check and render videos with KairoFrame, a fast native renderer. Inputs are HTML projects (HTML + CSS + a paused GSAP timeline, the Hyperframes format) with their footage, pictures and sound (music, voice-over, effects, volume curves, audio effect chains); any web page or built site (React, Vue, plain HTML) recorded on a virtual clock; and video clips and pictures stacked and joined into one film. Outputs are MP4, MOV, WebM, GIF, PNG frames or HLS, optionally HDR. Use when the user asks to create or edit a video, motion graphic, animated title, lower third, product promo, social clip or slideshow, to add music or voice-over, to turn a web page, app or slide deck into a video, to join clips and pictures, to recreate a video as HTML, or to render a Hyperframes project. Windows 64-bit and Linux x86-64.
---

# KairoFrame: HTML, web pages, footage, pictures and sound to video

KairoFrame renders a folder holding an `index.html` (the Hyperframes project format: plain HTML timed by `data-`
attributes and animated by a paused GSAP timeline) to a video file, with the footage, pictures and sound it places.
`kairoframe compose` also records any web page or built site and joins video clips and pictures into one film (section
6). It is a single native program; a Hyperframes project renders as it is.

**Command name:** always run it as `kairoframe`. Text the program prints (its help, `docs`, check findings, hints) and
the files `kairoframe init` writes may show the command under the engine's internal name: read every such command as
`kairoframe`.

## 1. Make sure KairoFrame is installed

Run `kairoframe doctor`. If the command is not found, try the installed program by its full path:

- Windows: `%LOCALAPPDATA%\KairoFrame\bin\kairoframe.exe doctor` (in Git Bash `"$LOCALAPPDATA/KairoFrame/bin/kairoframe.exe" doctor`)
- Linux: `~/.local/share/kairoframe/bin/kairoframe doctor`

If it is not there, install it with the script next to this file. It downloads KairoFrame, ffmpeg and a headless
Chrome (about 250 MB) and puts the program on the user's PATH:

```
# Windows: into %LOCALAPPDATA%\KairoFrame
powershell -NoProfile -ExecutionPolicy Bypass -File "<this skill's folder>\scripts\install.ps1"
# Linux (x86-64, glibc 2.38+): into ~/.local/share/kairoframe, linked as ~/.local/bin/kairoframe
bash "<this skill's folder>/scripts/install.sh"
```

On Linux the script lists any system libraries the headless browser is missing, with the command that installs them.

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

## 4b. Motion blur (KairoFrame's own effect)

`data-kf-fx="motion-blur(samples: 8, shutter: 180)"` on an element blurs that element as it moves; the element must be
`position: absolute` or `fixed` (`.clip` elements usually are). On the root element, or with
`kairoframe render --fx "motion-blur(samples: 8)"`, the whole film is blurred, video clips included (`--fx none` turns it
off). `samples` 2 to 64 (more is smoother; fast moves need 16 or more), `shutter` 1 to 360 degrees (180 = film look).
Frames where nothing moves cost nothing extra; on an element it adds about 10% to a render, on the whole film about 2x.
Look at a moving moment with `kairoframe frame --at <t>`: separate copies mean too few samples. `kairoframe docs`
lists every effect and its parameters.

## 5. Sound

Sound comes from `<audio>` elements and from `<video data-has-audio="true">` (other videos are silent). Any format
ffmpeg reads works (mp3, wav, m4a/aac, ogg, flac, ...); put the files in `assets/`.

```html
<audio src="assets/music.mp3" data-start="0" data-duration="12" data-volume="0.4" data-fade-in="0.5" data-fade-out="1.5"></audio>
<audio src="assets/voice.wav" data-start="1.2" data-media-start="3" data-duration="8"></audio>
```

- `data-media-start` trims the start of the file; `data-volume` (0 to 1), `data-fade-in`, `data-fade-out` in seconds.
- `data-automation` moves volume or speed over time (speed keeps the pitch); `data-fx-chain` applies effects such as
  EQ, compressor, limiter, gate, reverb, delay, chorus, pitch shift; clips with `data-audio-group` are mixed and
  processed together. `kairoframe docs` ("Sound and footage") has the exact JSON for these.
- The rendered MP4, MOV and WebM carry the mixed sound track.

## 6. Web pages, video clips and pictures: `kairoframe compose`

`kairoframe compose spec.json --json` renders a film of **segments played one after the other**, each a **stack of
layers**: a `page` (any built site or web page, served from a local folder), a `video` file, or an `image` (PNG with
alpha). Everything is composited in memory and encoded once.

```json
{
  "version": 1, "width": 1920, "height": 1080, "fps": 30,
  "output": "C:/work/out/film.mp4", "timing": "C:/work/out/timing.json",
  "segments": [
    { "name": "intro", "duration": null, "layers": [ { "type": "video", "src": "C:/work/intro.mp4" } ] },
    { "name": "demo", "duration": 12,
      "layers": [
        { "type": "page", "root": "C:/work/site/dist", "entry": "index.html", "query": "demo=1",
          "ready_selector": "#app", "duration": 12 },
        { "type": "video", "src": "C:/work/presenter.mp4", "crop": { "x": "center", "y": 0, "w": 720, "h": 720 },
          "resize": { "w": 360, "h": 360 }, "x": 1500, "y": 660 },
        { "type": "image", "src": "C:/work/logo.png", "x": 60, "y": 40 } ] }
  ]
}
```

- All paths absolute. The first layer of a segment must cover the whole frame. `"duration": null` = the length of the
  segment's first layer (a video). A layer that ends holds its last frame until the segment ends.
- A `page` layer runs its timers, `requestAnimationFrame`, `Date` and CSS animations on a virtual clock that moves to each
  frame's time, so its animation is exact; `init_script` runs before the page's own scripts (seed localStorage, set
  flags), and the page counts from 0 once `ready_selector` exists and the fonts are loaded.
- `video` layers are decoded natively: `crop`, then `resize`, then an optional grayscale `mask` PNG; `x`, `y` place them.
- The output is **picture only**. The timing file gives each segment's start frame; to add sound, put the film in an
  HTML project as a `<video>` with `<audio>` beside it, or mux a sound track with ffmpeg
  (`ffmpeg -i film.mp4 -i sound.m4a -c:v copy -c:a aac -shortest out.mp4`).
- `--dry-run` checks the spec and writes the timing file without rendering.

## 7. Recreating an existing video as HTML

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
