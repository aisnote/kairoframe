---
description: Install or update KairoFrame (Windows 64-bit) with ffmpeg and a headless Chrome
---

Install or update KairoFrame on this machine. Run the installer that comes with this plugin:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/kairoframe/scripts/install.ps1" -NoAgents
```

If `${CLAUDE_PLUGIN_ROOT}` is not filled in, find `install.ps1` under the `kairoframe` plugin's
`skills/kairoframe/scripts` folder. When it finishes, show the user the `doctor` lines it printed and the path of
`kairoframe.exe`. (`-NoAgents`: this plugin already gives Claude Code the skill; without it the script also registers
the skill with Codex CLI and Gemini CLI.) If a download fails, report which one and suggest running the command again.
