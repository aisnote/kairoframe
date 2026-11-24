# ScreenCap（测试版）— 鼠标触发截帧 + 鼠标轨迹记录

Windows 原生截屏工具：Win32 + DXGI Desktop Duplication 截屏，WIC 存 PNG，Media Foundation 调显卡硬件编码视频。截下来的帧不带系统光标，鼠标按完整轨迹单独记录，后期合成视频时重绘鼠标动画。

## 下载

Windows 10 2004+ / Windows 11，64 位。单文件 `screencap.exe`，不需要安装，不依赖其他 DLL。

SHA-256: `252f138cae37affab0e40a309e38d1b2750d5e14831413fb8c0d931b7cac5012`

## 使用

启动后屏幕右上角出现一个置顶小窗，它**不抢焦点**，**本身也不会被截进画面**：

| 按钮 | 作用 |
|---|---|
| 开始 | 新建一次会话，开始监听鼠标 |
| 暂停 / 继续 | 暂停期间不记录、不截帧 |
| 结束 | 等待写盘和视频收尾完成后关闭会话 |
| 连续截: 开/关 | 打开后按 30fps 连续截帧 |
| 目录 | 打开输出目录 |

截帧规则：

- **左 / 右 / 中键**：按下截 1 帧，抬起截 1 帧，存**无损 PNG**，记录哪个键、按下还是抬起。
  - 按下帧：取点击瞬间已经显示的画面（`DownDelayMs=0`）。
  - 抬起帧：延时 `UpDelayMs`（默认 100ms），再取这之后 DWM 合成的**第一张新画面**，保证截到完整的反应帧。画面静止时最多再等 `FreshFrameGraceMs`。
  - 画面和上一张 PNG 完全相同时不再存文件，记录里用 `duplicate_of` 指向原帧。
- **滚轮**：滚动时自动按 30fps 连续截帧，停止滚动 `WheelIdleMs`（500ms）后结束。
- **连续截 / 滚轮帧**：用显卡硬件编码（NVENC / Quick Sync / AMF）写成 MP4，每段连续截帧一个文件。编码器不可用时自动改存 PNG。
- **连续截打开时**：点击和滚轮不额外截帧，只把事件 id 标到下一帧的 `events` 里，时间轴保持均匀。
- **截取范围**：鼠标下那个窗口所在的整个显示器，支持多显示器。
- 在控制小窗上的点击会被忽略。侧键（x1/x2）只记录，不截帧。

## 占用空间（4K，30fps）

| 方式 | 2 分钟连续截 |
|---|---|
| 不压缩 | 约 90 GB |
| PNG（`VideoCodec=off`） | 估计 7–55 GB，取决于画面内容 |
| **H.264 硬件编码（默认）** | **≤ 约 450 MB**（自动码率 30 Mbps 封顶，静态界面会小很多） |

自动码率是每像素每帧 0.12 bit：4K30 约 30 Mbps，1080p30 约 7.5 Mbps，可以用 `VideoBitrateMbps` 指定。

写盘队列有内存上限（`MaxEncodeQueueMB`），超出的帧会丢弃并在记录里标 `dropped`，不会把内存撑爆。

## 配置 `screencap.ini`（exe 同目录，首次运行自动生成，缺的项会自动补上）

```ini
[capture]
DownDelayMs=0
UpDelayMs=100
FreshFrameGraceMs=50
ContinuousFps=30
WheelIdleMs=500
EncoderThreads=0      ; PNG 编码线程，0 = 自动
RecordMouseMove=1
OutputDir=            ; 空 = exe 目录\captures
VideoCodec=h264       ; h264 | hevc | off（off = 连续帧也存 PNG）
VideoBitrateMbps=0    ; 0 = 自动
MaxEncodeQueueMB=2048 ; PNG 写盘队列内存上限
```

## 输出格式

```
captures/session_20261123_204818/
  session.json     会话信息：开始时间、QPC 频率、配置、显示器列表、结束统计
  frames.jsonl     每帧一行
  events.jsonl     每个鼠标/控制事件一行（含全部移动轨迹）
  cursors.jsonl    出现过的光标形状（PNG + 热点）
  frames/000000.png ...      点击帧
  video/seg_0001_m0.mp4 ...  连续截 / 滚轮帧（seg = 段号，m = 显示器）
  cursors/c1.png ...
```

- 所有 `t_us` 都是从会话开始算起的**微秒**，时间源是 QueryPerformanceCounter。点击、滚轮、帧另外带 `wall` 本地时间（毫秒）。
- 坐标都是物理像素（Per-Monitor DPI Aware V2）。`mx/my` 是相对该帧所在显示器左上角的坐标。

**frames.jsonl**，一帧的画面在下面三处之一：
```json
{"index":1,"file":"frames/000001.png","trigger":"left_up","t_us":162500,"event_t_us":62500,"delay_ms":100, ...}
{"index":7,"file":"frames/000001.png","duplicate_of":1,"trigger":"right_down", ...}
{"index":41,"file":null,"video":"video/seg_0002_m0.mp4","video_frame":12,"video_pts_us":400000,"segment":2,"trigger":"continuous","events":[14], ...}
```
其余字段：`present_t_us`（这张画面实际被显示的时间）、`captured_t_us`、`event_id`、`monitor`、`monitor_rect`、`width/height`、`mouse{x,y,mx,my}`、`mouse_at_capture`、`buttons`、`cursor`、`window{hwnd,title,class,pid,process,rect}`、`events`（标到本帧的事件 id）。
`dropped` 不为空表示这一帧丢了：`encoder_backlog` 是 PNG 写盘跟不上，`video_backlog` 是视频编码跟不上。

`video_frame` 是该帧在 MP4 里的序号，从 0 开始，按 30fps 连续排列。`video_pts_us` 是它在 MP4 里的时间戳。

**events.jsonl** 的 `type` 取值：
- 鼠标事件：`move` `down` `up` `wheel` `cursor`（光标形状变化）
- 会话控制：`session_start` `pause` `resume` `session_stop`
- 连续截：`continuous_start` `continuous_stop`（带 `segment`）
- 视频：`video_start`（记录用了哪个编码器、是否硬件、码率、分辨率）
- 异常：`video_fallback`（编码器不可用，改存 PNG）、`capture_failed`

## 实现要点

- 每个显示器一个 Desktop Duplication 线程，在 GPU 上保留最近 4 张画面和各自的显示时间。每个截帧请求按时间戳挑对应的那一张。
- 连续帧**全程不离开 GPU**：显存里拷一份，交给 Media Foundation 硬件编码器，由显卡完成颜色转换和编码。
- 点击帧画面不变时只读回一次显存。PNG 编码在后台线程池里做，有内存上限。
- 全局鼠标钩子 `WH_MOUSE_LL` 跑在独立的最高优先级线程上，回调里只打时间戳、入队。
- 30fps 定时用高精度可等待定时器，按绝对时间对齐，不累积漂移。

## 自测

```bat
screencap.exe --selftest <输出目录> [--synthetic] [--seconds N] [--codec h264|hevc|off]
```
新机器上建议先跑：`screencap.exe --selftest C:\temp\sc_test --seconds 10`，会截真实屏幕。然后看 `selftest.txt` 里的帧数和丢帧数，再看 `events.jsonl` 里的 `video_start`，确认 `"hardware":true`，也就是用的是显卡编码。
不产生真实鼠标输入，用合成事件走完整流程：3 次点击、4 格滚轮、N 秒连续截（中间带一次点击）。结果写到 `<输出目录>\selftest.txt`，包括帧数、PNG 和 MP4 的大小、每分钟视频占用、丢帧数。
`--synthetic` 用软件生成的 4K 画面代替显示器，适用于没有活动桌面的环境（例如已断开的远程桌面会话）。

## 已知限制

- 被截程序如果以管理员身份运行，ScreenCap 也要以管理员身份运行，否则收不到该窗口上的鼠标事件。
- 锁屏、UAC 安全桌面期间无法截图，会自动重连，期间的请求记为 `capture_failed`。
- MP4 在「结束」时才写完。程序崩溃时，正在写的那一段视频会损坏，PNG 和记录文件不受影响。
- 旋转显示器和奇数分辨率显示器的连续帧会改存 PNG。旋转方向的转换未在真机上验证。
- HDR 显示器输出为转换后的 SDR（8 位 BGRA）。
