# ScreenCap（测试版）— 鼠标触发截帧 + 鼠标轨迹记录

Windows 10 2004+ / Windows 11，64 位。单文件 `screencap.exe`，不需要安装，不依赖其他 DLL。

SHA-256: `3a36b243da61f0074dea69f080636065c28ebcc3b4c2b04acc8713721fbe863d`

截下来的帧**不带系统光标**，鼠标按完整轨迹单独记录，后期用 KairoFrame 合成视频时重绘鼠标动画。

## 使用

双击 `screencap.exe`，屏幕右上角出现一个置顶小窗。它不抢焦点，本身也不会被截进画面：

| 按钮 | 作用 |
|---|---|
| 开始 | 新建一次会话，开始监听鼠标 |
| 暂停 / 继续 | 暂停期间不记录、不截帧 |
| 结束 | 等待写盘完成后关闭会话 |
| 连续截: 开/关 | 打开后按 30fps 连续截帧 |
| 目录 | 打开输出目录（默认 exe 旁边的 `captures\`） |

截帧规则：

- **左 / 右 / 中键**：按下截 1 帧，抬起截 1 帧，记录哪个键、按下还是抬起。
  - 按下帧：点击瞬间已经显示的画面。
  - 抬起帧：延时 100ms 后的第一张新画面，保证截到完整的反应帧。
- **滚轮**：滚动时自动按 30fps 连续截帧，停止滚动 500ms 后结束。
- **连续截打开时**：点击和滚轮不额外截帧，只把事件 id 标到帧上。
- **截取范围**：鼠标下那个窗口所在的整个显示器，支持多显示器。
- 每个事件、每一帧都带微秒时间戳（从会话开始计时）和本地时间。

## 快速自测

```bat
screencap.exe --selftest C:\temp\sc_test
```
用合成的鼠标事件（不会动你的鼠标）截真实屏幕约 3 秒，结果写到 `C:\temp\sc_test\selftest.txt`。正常结果大约 60 帧，失败数为 0。

## 配置 `screencap.ini`（exe 同目录，首次运行自动生成）

```ini
[capture]
DownDelayMs=0
UpDelayMs=100
FreshFrameGraceMs=50
ContinuousFps=30
WheelIdleMs=500
EncoderThreads=0      ; 0 = 自动
RecordMouseMove=1
OutputDir=            ; 空 = exe 目录\captures
```

## 输出格式

```
captures/session_YYYYMMDD_HHMMSS/
  session.json     会话信息：开始时间、配置、显示器列表、结束统计
  frames.jsonl     每帧一行：trigger、t_us、鼠标位置、按键、光标、窗口、标记的事件
  events.jsonl     每个鼠标事件一行：move/down/up/wheel/cursor/... 带 t_us 和坐标
  cursors.jsonl    出现过的光标形状（PNG + 热点）
  frames/000000.png ...
  cursors/c1.png ...
```
坐标都是物理像素。`mx/my` 是相对该帧所在显示器左上角的坐标。

## 已知限制

- 被截程序如果以管理员身份运行，ScreenCap 也要以管理员身份运行。
- 锁屏、UAC 安全桌面期间无法截图，期间的请求记为 `capture_failed`。
- 已断开的远程桌面会话里没有可截取的画面。
- 旋转显示器尚未在真机上验证。
