# 06 · 报错急救：从现象到原因

> 排查原则：**先看日志最后 20 行，再改一个变量，改完立刻验证。**
> 不要一次改五个地方，否则不知道是谁修好的。

---

## 1. 启动阶段

### 1.1 双击 bat 一闪而过

**原因**：脚本报错后立即退出。

**排查**：

```powershell
cd /d D:\ComfyUI
.\start-lowvram.bat
```

或直接运行：

```powershell
D:\ComfyUI\python_embeded\python.exe -s D:\ComfyUI\ComfyUI\main.py --lowvram
```

看最后几行。

常见：

- `python.exe` 路径不对 → 检查 `python_embeded`
- `main.py` 不存在 → 解压不完整
- 端口占用 → 换 `--port 8189`

---

### 1.2 `Address already in use`

**原因**：8188 被别的程序占用（另一个 ComfyUI、旧进程）。

**排查**：

```powershell
Get-NetTCPConnection -LocalPort 8188 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

**处理**：

```powershell
# 找到 PID 后
Stop-Process -Id <PID> -Force
```

或换端口：

```bat
--port 8189
```

---

### 1.3 `No module named 'torch'`

**原因**：用了系统 Python，或者下成了 CPU 包。

**处理**：

- 必须用 `D:\ComfyUI\python_embeded\python.exe`。
- 重下 `ComfyUI_windows_portable_nvidia.7z`。

---

### 1.4 `torch.cuda.is_available()` False

**原因**：

1. 驱动太旧
2. 下成 CPU/AMD 包
3. 笔记本没用独显
4. 系统 Python 的 torch 是 CPU 版

**处理**：

1. 更新 NVIDIA 驱动。
2. 确认包名含 `nvidia`。
3. NVIDIA 控制面板把 `python.exe` 设为高性能。
4. 重启。

---

### 1.5 启动卡 2–5 分钟

**原因**：插件太多 / 插件导入失败。

**处理**：

```bat
start-safe-mode.bat
```

如果能快速启动，说明是插件问题。逐个禁用：

```text
custom_nodes\xxx → custom_nodes.disabled\xxx
```

---

### 1.6 `IMPORT FAILED`

**原因**：插件依赖不匹配、Python 版本不对、缺包。

**处理**：

1. 先 `--disable-all-custom-nodes` 确认基础功能。
2. 看是哪个插件报错。
3. 不用的插件移到 `custom_nodes.disabled`。
4. 需要的插件，按它的 README 装依赖。

---

## 2. 模型阶段

### 2.1 模型下拉框为空

**排查顺序**：

1. 文件在不在：

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\models\checkpoints"
```

2. 扩展名是不是 `.safetensors` / `.ckpt`。
3. 文件是不是 `.part`。
4. 按 `R` 刷新。
5. 重启 ComfyUI。
6. 检查 `extra_model_paths.yaml`。

---

### 2.2 模型能看到，加载报错

**原因**：

- 文件没下完
- 下到了网页/LFS 指针
- 格式不支持
- 文件损坏

**处理**：

```powershell
Get-Item "D:\...\模型.safetensors" | Select-Object Name,Length
```

对照清单大小。太小就重下。

---

### 2.3 下到几 KB 的 `.safetensors`

**原因**：下到了 Git LFS 指针或 HTML 页面。

**处理**：

- 用 `scripts/download-models.py`。
- 或从 ModelScope 的“模型文件”页下。
- 删掉坏文件，重下。

---

## 3. 出图阶段

### 3.1 `OutOfMemoryError` / `Allocation on device failed`

**按顺序**：

1. 分辨率降到 512。
2. `batch_size` 改 1。
3. 关游戏/浏览器视频/模拟器。
4. 用 `VAE Decode (Tiled)`，tile 256–512。
5. 换 SD1.5。
6. 启动加 `--novram`。
7. 虚拟内存调到 32–64GB。
8. 重启电脑。

---

### 3.2 全黑图

**原因**：

- VAE 不匹配
- 模型损坏
- 步数/CFG 异常
- 负面词过强

**处理**：

1. 换 VAE。
2. 重下模型。
3. steps 20 / cfg 7 回到默认。
4. 清空负面词试一次。

---

### 3.3 花屏 / 噪点

**原因**：

- 模型没下完
- fp16/fp32 不匹配
- VAE 不对
- 分辨率不是 64 的倍数

**处理**：

- 尺寸改成 512×512、768×768。
- 换 VAE。
- 重下模型。

---

### 3.4 图很糊

**原因**：

- 步数太低
- 分辨率太低
- 模型不适合
- 没放大

**处理**：

- steps 25–30。
- 768 出图。
- 换 RealVisXL / Juggernaut。
- 加 4x 放大。

---

### 3.5 手崩 / 多手指

**原因**：SD1.5 的极限。

**处理**：

- 负面词加 `bad hands, extra fingers`。
- 用 FaceDetailer / HandDetailer。
- 换 SDXL。
- 手部 LoRA。
- 构图避开复杂手部动作。

---

### 3.6 画面重复 / 双头

**原因**：分辨率超过模型原生，或提示词冲突。

**处理**：

- 回到 512/768。
- 减少 `1girl, 2girls` 冲突。
- 降 CFG。
- 换模型。

---

### 3.7 颜色发灰 / 发绿

**原因**：VAE 不对。

**处理**：

- 换 `vae-ft-mse-840000`（SD1.5）或 `sdxl_vae`（SDXL）。
- 确认没有混用 SD1.5/SDXL 的 VAE。

---

## 4. 性能阶段

### 4.1 出图特别慢

**排查**：

| 可能 | 检查 |
|---|---|
| 用了 CPU | `torch.cuda.is_available()` |
| 分辨率太高 | 512 对比 |
| 步数太高 | 20 对比 |
| 模型太大 | SD1.5 对比 |
| 内存不够在 swap | 任务管理器 |
| 机械盘加载 | 模型放 SSD |
| 笔记本降频 | 温度/电源模式 |
| 后台占用 | 关游戏/浏览器 |

---

### 4.2 第二次出图反而更慢

**原因**：

- 换了模型/分辨率，重新加载
- 内存不足，开始 swap
- 插件缓存

**处理**：

- 同样参数连续跑两次对比。
- 关后台程序。
- 重启 ComfyUI。

---

### 4.3 启动越来越慢

**原因**：插件越装越多。

**处理**：

- 清理不用的插件。
- 用 `--disable-all-custom-nodes` 对比。
- 把不用的移到 `custom_nodes.disabled`。

---

## 5. 磁盘阶段

### 5.1 磁盘满了

```powershell
# 看大文件
Get-ChildItem "D:\ComfyUI" -Recurse -File |
  Sort-Object Length -Descending |
  Select-Object -First 20 FullName,@{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

清理：

- `output` 旧图
- `.part` 半成品
- `_download` 安装包
- 不用的模型
- `__pycache__`

### 5.2 模型删了但空间没释放

- 可能有进程占用。
- 重启后删。
- 检查回收站。

---

## 6. 网络阶段

### 6.1 下载速度为 0

- 换 ModelScope。
- 换 CNB。
- 换 hf-mirror。
- 用 `--source` 指定。
- 断点续传重跑。

### 6.2 SSL 错误

- 换网络。
- 关闭代理/VPN 再试。
- 用 `curl.exe` 手动下。
- 不要关闭证书校验（不安全）。

### 6.3 GitHub 打不开

- 用镜像/加速。
- 让朋友下好传网盘。
- 用国内整合包过渡。

---

## 7. 插件阶段

### 7.1 装了插件后启动失败

```text
1. start-safe-mode.bat 能启动 → 插件问题
2. 把最近装的插件移出 custom_nodes
3. 重启
4. 确认基础功能
5. 逐个装回
```

### 7.2 插件缺依赖

看插件目录的 `requirements.txt`：

```powershell
D:\ComfyUI\python_embeded\python.exe -m pip install -r requirements.txt
```

> 不要用系统 pip；不要一次装一堆。

### 7.3 插件版本不兼容

- 看插件 README 支持的 ComfyUI 版本。
- 回退 ComfyUI 版本。
- 或换同类插件。

---

## 8. 日志在哪

| 日志 | 位置 |
|---|---|
| 控制台 | 启动窗口 |
| ComfyUI 日志 | 控制台输出 |
| 浏览器控制台 | F12 → Console |
| Windows 事件 | 事件查看器 |

出问题先复制**最后 20 行**，不要只发“报错了”。

---

## 9. 一张图总结排查顺序

```text
打不开网页
├─ 服务没起来 → 看控制台
├─ 端口占用 → 换端口
└─ 浏览器问题 → 换浏览器/无痕

服务起来了但没模型
├─ 放错目录
├─ 没刷新
└─ 文件坏了

能出图但 OOM
├─ 降分辨率
├─ batch=1
├─ Tiled VAE
├─ --lowvram / --novram
└─ 关后台

出图质量差
├─ 步数/CFG
├─ VAE
├─ 模型
└─ 放大
```

---

## 10. 本章检查清单

- [ ] 知道日志在哪看
- [ ] 会判断“服务问题”还是“模型问题”
- [ ] 会看 OOM
- [ ] 会换 VAE
- [ ] 会安全模式启动
- [ ] 会清理 `.part` 和旧输出
- [ ] 一次只改一个变量