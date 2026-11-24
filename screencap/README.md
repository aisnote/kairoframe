# ScreenCap（测试版）— 无鼠标录屏 + 鼠标/交互数据记录 + 自动成片

Windows 原生录屏工具：录一整段**不含鼠标**的视频，同时把鼠标轨迹、点击、滚轮、光标形状、点击到的界面元素、声音都按同一条时间轴记录下来。点「成片」就用这些数据自动剪辑出最终视频：点击处平滑放大、重绘平滑的鼠标、去掉空闲片段（由 KairoFrame 渲染）。

技术栈：DXGI Desktop Duplication 截屏，Media Foundation 调显卡硬件编码（NVENC / Quick Sync / AMF），WIC 存 PNG，WASAPI 录音，UI Automation 识别控件。

## 下载

Windows 10 2004+ / Windows 11，64 位。单文件 `screencap.exe`，不需要安装，不依赖其他 DLL。

SHA-256: `68d87e0fa583685a994f98269b7a4f9af38b673831579bc053d0e60dd0e4ce58`

**新机器上建议先跑一次自测**（会录真实屏幕，测试期间可以放点声音、对着麦克风说话）：

```bat
screencap.exe --selftest C:\temp\sc_test --seconds 15 --audio --keys
```

然后看 `C:\temp\sc_test\selftest.txt`：
- 视频帧数接近预期，丢帧为 0，有 2 个以上 MP4。
- `first video_start` 里是 `"hardware":true`，也就是用的是显卡编码。
- audio 部分两个 WAV 的峰值音量不是 0%。

装好 KairoFrame 后，再试成片：`screencap.exe polish C:\temp\sc_test\session_...`（或者直接正常录一段，点「成片」）。

## 使用

启动后屏幕右上角出现一个置顶小窗，它**不抢焦点**，**本身也不会被录进画面**：

| 按钮 | 作用 |
|---|---|
| 开始 | 开始录屏 |
| 暂停 / 继续 | 暂停期间不录画面、不录声音、不记录事件 |
| 结束 | 写完视频和数据后关闭本次录制 |
| 录音: 开/关 | 同时录电脑声音和麦克风（可先打开再点「开始」） |
| 成片 | 把刚录完的内容自动剪辑成最终视频（见下文「成片」） |
| 目录 | 打开输出目录 |

- **录哪个显示器**：点「开始」时前台窗口所在的显示器（控制小窗不抢焦点，所以就是你正在用的那个程序）。也可以在 ini 里用 `RecordMonitor=N` 固定第 N 个显示器。
- **视频**：固定 30fps，画面里没有鼠标。每 5 分钟自动切一个文件，暂停后继续也会另起一个文件。程序崩溃时最多损失正在写的那一段。
- **点击快照**：左 / 右 / 中键按下和抬起时，各存一张无损 PNG。后期做「点击放大并定格」时用它，文字是锐利的。
  - 按下：取点击瞬间已经显示的画面。
  - 抬起：等 100ms 后取下一张新画面，也就是程序对点击做出反应之后的样子。
  - 画面跟上一张完全相同时不再存文件，记录里用 `duplicate_of` 指向原图。
- **点击到的界面元素**：每次按下时，后台用 UI Automation 查出鼠标下那个控件的名称、类型、精确矩形和两层父元素。后期可以把镜头对准被点的按钮或输入框。只读名称，不读输入框内容。
- **键盘活动**（默认关，`KeyboardActivity=1` 打开）：只记"什么时候按了键"，**不记是哪个键**；另外记录当前焦点元素的位置，可以做"打字时自动放大"。
- 在控制小窗上的点击会被忽略。

## 成片：自动剪辑成最终视频

录完点「成片」，或者在命令行运行 `screencap.exe polish [录制目录]`（不写目录时用最新一次录制）。ScreenCap 会在录制目录里生成一个 KairoFrame 工程 `index.html`，直接引用录到的视频、光标图片和 WAV，不复制任何文件；然后调用 [KairoFrame](https://github.com/aisnote/kairoframe) 渲染出 `polished.mp4`。

做了哪些处理：
- **自动放大**：点击前约 0.6 秒平滑放大到 2 倍，对准被点的控件（用录到的控件矩形；没有就对准点击位置）。几秒内的连续点击算一个镜头，镜头会平移到每次点击的位置。鼠标走出画面时镜头会跟随，最后一次点击后约 1.4 秒缩回全屏。打开了键盘活动时，打字也会放大到输入框。镜头不会移出画面边缘。
- **画质**：4K 录屏默认输出 1920×1080，所以 2 倍放大不损失清晰度。
- **重绘鼠标**：用录到的真实光标图片（没录到就用内置箭头），轨迹去抖但不滞后，按下时略微缩小，点击处有白色波纹。
- **空闲处理**：没有鼠标、键盘、声音超过 2 秒的片段，画面静止就直接剪掉（看不出跳变），画面在动（比如加载）就加速 4 倍，越长越快，最多 10 倍，前后各留 0.4 秒原速。暂停期间的空白也会去掉。
- **掐头去尾**：开头和结尾只有鼠标移动的部分会剪掉（比如最后移去点「结束」的那段），保留第一次和最后一次操作前后各 1.5 秒。
- **声音**：电脑声音和麦克风按剪辑后的时间轴放进去。

生成的文件：`index.html`（KairoFrame 工程，可以手改后用 `kairoframe render` 重新渲染）、`polish.json`（剪辑摘要：原长、成片长度、剪掉和加速的段数、放大次数）、`polished.mp4`。

需要先安装 KairoFrame（一行命令，见它的 README）：
```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/aisnote/kairoframe/main/install.ps1 | iex"
```

可调参数在 `screencap.ini` 的 `[polish]` 一节，命令行参数优先：

| ini | 命令行 | 默认 | 说明 |
|---|---|---|---|
| `AutoZoom` | `--no-zoom` | 1 | 是否自动放大 |
| `ZoomLevel` | `--zoom Z` | 2.0 | 放大倍数 |
| `IdleMode` | `--idle auto\|speed\|cut\|off` | auto | 空闲片段：静止就剪、在动就加速 / 都加速 / 都剪 / 不处理 |
| `IdleMinSeconds` | `--idle-min S` | 2 | 多久没操作算空闲 |
| `IdleSpeed` | `--idle-speed X` | 4 | 空闲加速倍数 |
| `TrimEnds` | `--no-trim` | 1 | 掐头去尾 |
| `OutputWidth` | `--width W` | 1920 | 输出宽度（按原比例，不放大） |
| `CursorScale` | `--cursor-scale X` | 1.0 | 鼠标大小 |
| `CursorSmoothMs` | `--smooth MS` | 40 | 鼠标去抖强度，0 = 原始轨迹 |
| `ClickRipple` | `--no-ripple` | 1 | 点击波纹 |
| `RenderQuality` | `--quality draft\|standard\|high` | standard | KairoFrame 渲染质量 |
| `KairoFramePath` | | 空 | kairoframe.exe 的位置，空 = PATH，然后 `%LOCALAPPDATA%\KairoFrame\bin` |
| | `--no-render` | | 只生成 index.html，不渲染 |

## 画质与空间（4K，30fps）

| `VideoQuality` | 编码 | 码率 | 每分钟 | 适用 |
|---|---|---|---|---|
| `standard` | H.264 | 约 30 Mbps | ≤ 225 MB | 不放大 |
| **`high`（默认）** | **HEVC** | **约 50 Mbps** | **≤ 375 MB** | 放大约 2 倍，文字仍清楚 |
| `lossless` | HEVC 定质量（95） | 按内容 | 约 0.5–1.5 GB | 放大很多倍 |

- 码率是平均码率上限，界面静止时文件会小很多。1080p 按像素数等比例缩小（约 1/4）。
- 显卡不支持 HEVC 时会自动改用 H.264。实际用了哪个编码器、是否硬件编码，记录在 `events.jsonl` 的 `video_start` 里。
- 显卡编码时颜色信息按 1/4 分辨率保存（4:2:0），放大后彩色小字的边缘会略糊，这时用点击快照。
- 声音：每路约 11 MB/分钟。

## 录音

- **电脑声音**：录 Windows 默认播放设备正在播放的声音（WASAPI loopback）。**麦克风**：录默认录音设备。两路分别存成 16 位 PCM WAV。
- **跟画面对齐**：每个音频包都带硬件时间戳，跟画面用同一条时钟（QPC）。电脑没出声的时候 Windows 不送数据，这段会自动补静音。所以 WAV 的第 n 个采样点就在 `audio_start.t_us + n / sample_rate`。
- 设备被拔掉会自动重连，另起一个文件 `p2`、`p3`……
- WAV 文件头每秒更新一次，程序崩溃时已录的部分也能正常播放。
- 找不到设备时只在记录里写 `audio_error`，状态栏显示 ✗，录屏不受影响。

## 配置 `screencap.ini`（exe 同目录，首次运行自动生成，缺的项会自动补上）

```ini
[capture]
VideoFps=30
VideoQuality=high       ; standard | high | lossless
VideoCodecForce=        ; 空 = 按画质选；h264 / hevc 强制
VideoBitrateMbps=0      ; 0 = 按画质自动
ChunkMinutes=5          ; 每几分钟切一个 MP4
RecordMonitor=0         ; 0 = 开始时前台窗口所在的显示器；N = 第 N 个显示器
Snapshots=1             ; 点击时存无损 PNG
DownDelayMs=0           ; 按下快照的延时
UpDelayMs=100           ; 抬起快照的延时
FreshFrameGraceMs=50
EncoderThreads=0        ; PNG 编码线程，0 = 自动
MaxEncodeQueueMB=2048   ; PNG 写盘队列内存上限，超出的快照丢弃并标记
RecordMouseMove=1
UiaElements=1           ; 记录点击到的界面元素
KeyboardActivity=0      ; 记录按键时间（不含按键内容）和焦点元素
AudioSystem=1           ; 录音按钮是否录电脑声音
AudioMic=1              ; 录音按钮是否录麦克风
AudioSystemDevice=      ; 空 = 默认播放设备，否则填设备名的一部分
AudioMicDevice=         ; 空 = 默认录音设备，否则填设备名的一部分
OutputDir=              ; 空 = exe 目录\captures
```

## 输出格式

```
captures/session_20261123_233440/
  session.json        开始时间、配置、所有显示器（标明录的是哪个）、结束统计
  video/rec_0001.mp4  录屏（无鼠标），文件号 = video_index 里的 segment
  video_index.csv     每个视频帧一行
  clicks/000000.png   点击快照
  snapshots.jsonl     每张快照一行
  events.jsonl        所有事件（鼠标、键盘、界面元素、录制、音频……）
  cursors/c1.png + cursors.jsonl   光标形状（PNG + 热点）
  audio/system_s0001_p1.wav, mic_s0001_p1.wav
```

**时间和坐标**
- 所有 `t_us` 都是从录制开始算起的**微秒**，时间源是 QueryPerformanceCounter。视频、快照、事件、音频都在这一条时间轴上。
- 坐标都是物理像素（Per-Monitor DPI Aware V2）。`x/y` 是桌面坐标，`mx/my` 是相对被录显示器左上角的坐标，可以直接对应到视频画面。

**video_index.csv**（按 `t_us` 排序）
```
t_us,segment,file,video_frame,pts_us,changed,present_t_us,dropped
3005,1,video/rec_0001.mp4,0,0,1,1200,
36338,1,video/rec_0001.mp4,1,33333,0,1200,
```
- `video_frame`：该帧在 MP4 里的序号，从 0 开始。
- `changed`：跟上一帧比画面是否变化，可以用来找空闲片段。
- `dropped`：非空表示这一帧丢了。

**events.jsonl** 的 `type`：
- 鼠标：`move`、`down`、`up`、`wheel`、`cursor`（光标形状变化）。点击事件带 `button`、`mx/my`、`window`（窗口标题、进程、矩形）、`snapshot`。
- 界面元素：`element`（`uia.event_id` 对应那次点击），`focus`（打字时的焦点元素）。
- 键盘：`key_down`、`key_up`（只有时间）。
- 录制：`session_start`、`record_start`、`record_stop`、`video_chunk`、`video_start`（编码器信息）、`pause`、`resume`、`session_stop`。
- 音频：`audio_start`（`t_us` = 该 WAV 第 0 个采样点的时间）、`audio_stop`、`audio_error`。
- 异常：`capture_failed`、`video_fallback`（编码器不可用，画面改存 `frames/*.png`）。

**snapshots.jsonl** 示例：
```json
{"index":0,"file":"clicks/000000.png","trigger":"left_down","t_us":3005,"event_id":2,"delay_ms":0,"present_t_us":1200, "mouse":{"x":640,"y":360,"mx":640,"my":360},"buttons":["left"],"cursor":"c1","window":{...}}
```

## 自测

```bat
screencap.exe --selftest <输出目录> [--seconds N] [--chunk 秒] [--quality standard|high|lossless] [--audio] [--keys] [--synthetic]
```
不产生真实鼠标或键盘输入，用合成事件走完整流程：3 次点击、滚轮、鼠标移动、一次暂停和继续。加 `--keys` 时还有 5 次按键。结果写到 `<输出目录>\selftest.txt`，包括视频帧数（含预期值）、MP4 个数和每分钟大小、丢帧、快照、各类事件计数、实际用的编码器，加 `--audio` 时还有每个 WAV 的峰值音量。
`--synthetic` 用软件生成的 4K 画面代替显示器，适用于没有活动桌面的环境。

## 实现要点

- 截屏线程在 GPU 上保留最近 4 张画面和各自的显示时间，每个 30fps 时刻取当时正在显示的那一张。视频帧**全程不离开显存**，直接交给硬件编码器。
- 快照按时间戳取对应画面，画面不变时只读回一次显存，PNG 编码在后台线程池里做，有内存上限。
- 全局鼠标和键盘钩子跑在独立的最高优先级线程上，回调里只打时间戳、入队。
- UI Automation 查询在独立线程里做，超时 1 秒，界面卡死的程序不会拖慢录制。
- 30fps 定时用高精度可等待定时器，按绝对时间对齐，不累积漂移。分段切换时时间轴无缝衔接。

## 已知限制

- 被录程序如果以管理员身份运行，ScreenCap 也要以管理员身份运行，否则收不到该窗口上的鼠标事件，也查不到它的控件。
- 只录一个显示器。鼠标移到其他显示器上时，事件照常记录（`on_recorded_monitor:false`），但没有画面和快照。
- 锁屏、UAC 安全桌面期间无法截图，期间的帧记为 `capture_failed`。
- 旋转显示器和奇数分辨率显示器无法用硬件编码，画面会改存 PNG（很大）。
- HDR 显示器输出为转换后的 SDR（8 位）。
- 录音过程中在 Windows 里切换默认设备不会自动跟过去，要重新打开录音（拔掉设备则会自动切换）。
- 麦克风需要在「设置 → 隐私 → 麦克风」里允许桌面应用访问。
