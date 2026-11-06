# AI-DEPLOY.md · 给 AI 的 ComfyUI 低显存部署指令

> **Language / 语言**: 中文 | [English](AI-DEPLOY.en.md)

> 这份文档是给 **AI 助手**读的，不是给人读的。
> 人只需要把整份文档复制给 AI，然后说“按这个部署”。
>
> 目标机器：Windows 10/11 + NVIDIA 显卡（4GB / 6GB / 8GB 显存优先）
> 目标结果：ComfyUI 能启动、能看到模型、能生成第一张 512×512 的图。
> 文档版本：2026-11 · 对应 ComfyUI v0.42.1

---

## 0. 你现在的角色

你是部署执行者，不是聊天助手。按下面的协议工作：

1. **先取证，再动手**：每一步先运行检查命令，根据真实输出决定分支，不要凭经验猜。
2. **一次只做一件事**：执行一个步骤 → 贴出命令和原始输出 → 确认成功 → 再做下一步。
3. **不编造**：没运行的命令不说“已完成”；没看到的输出不说“应该没问题”。
4. **不越界**：不删除用户已有模型/工程；不装与任务无关的软件；不写入任何密钥。
5. **失败就降级**：按本文的备用路径走，不要卡在一个源上。
6. **最终交付必须带证据**：命令原文 + 实际输出 + 验收结果。

---

## 1. 开工前，只问用户 3 个问题

如果信息已经能从系统读到，就不要问。

1. 安装到哪个盘？默认 `D:\ComfyUI`，至少留 30GB（standard 档建议 60GB）。
2. 显卡是什么？如果不确定，你直接运行 `nvidia-smi` 读。
3. 网络能不能访问 GitHub / Hugging Face？不能也没关系，走 ModelScope / CNB。

**不要问**“你想用什么模型”“你要不要装插件”——先跑通最小闭环，再按需扩展。

---

## 2. 硬约束

- 只支持 64 位 Windows。
- 只支持 NVIDIA 显卡（AMD/Intel 请换对应 portable 包，本文不展开）。
- 安装路径不能含中文和空格。
- 不要用系统 Python；必须用便携版自带的 `python_embeded\python.exe`。
- 不要执行来源不明的 `.exe`；只下 `.7z` 并解压。
- 不要开 `--highvram`。
- 不要一次装多个自定义节点；先保证原生出图。
- 不要修改 `C:\Windows`、不要改全局环境变量（除非用户明确同意）。
- 不要提交/上传用户的模型、输出图、API Key。

---

## 3. 阶段 0 · 环境取证

按顺序运行，记录原始输出。

```powershell
# 0.1 系统
[System.Environment]::OSVersion.VersionString
(Get-CimInstance Win32_OperatingSystem).OSArchitecture

# 0.2 显卡
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv

# 0.3 内存
[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)

# 0.4 目标盘空间
Get-PSDrive D | Select-Object Name,@{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}

# 0.5 是否已装过
Test-Path "D:\ComfyUI\ComfyUI\main.py"
```

### 判定表

| 结果 | 分支 |
|---|---|
| `nvidia-smi` 失败 | 停止。告诉用户装 NVIDIA 驱动，或改用 CPU/云端。不要继续。 |
| 显存 < 4GB | 只用 `minimal` 档 + SD1.5 + `--novram`。 |
| 显存 4–5GB | `minimal` 档 + `start-4gb.bat`。 |
| 显存 6–7GB | `standard` 档 + `start-lowvram.bat`。 |
| 显存 ≥ 8GB | `standard` 档 + `start-lowvram.bat`；可试 SDXL 1024。 |
| 磁盘 < 30GB | 停止。让用户清理或换盘。 |
| `main.py` 已存在 | 跳到阶段 3（启动验证），不要覆盖安装。 |

**证据格式**：

```text
[阶段 0]
命令：nvidia-smi --query-gpu=...
输出：NVIDIA GeForce RTX 3060 Laptop GPU, 6144 MiB, 560.94
判定：6GB → standard 档 + lowvram
```

---

## 4. 阶段 1 · 安装 ComfyUI

### 4.1 首选：仓库脚本

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -InstallDir "D:\ComfyUI"
```

期望结果：

- 退出码 0
- `D:\ComfyUI\ComfyUI\main.py` 存在
- `D:\ComfyUI\python_embeded\python.exe` 存在
- `D:\ComfyUI\start-lowvram.bat` 存在

### 4.2 脚本失败时：手动安装

1. 下载：
   `https://github.com/Comfy-Org/ComfyUI/releases/download/v0.42.1/ComfyUI_windows_portable_nvidia.7z`
2. 如果 GitHub 不通，用备用：
   - 让用户提供已下载的 `.7z` 路径，执行 `install-windows.ps1 -Archive "<路径>" -SkipDownload`
   - 或从 ModelScope / 国内镜像找同名包（核对大小约 2GB）
3. 用 7-Zip 解压到 `D:\ComfyUI`。
4. 确认目录结构：

```text
D:\ComfyUI\ComfyUI\main.py
D:\ComfyUI\python_embeded\python.exe
```

### 4.3 安装后立即验证 Python / Torch / CUDA

```powershell
D:\ComfyUI\python_embeded\python.exe -c "import torch; print('torch', torch.__version__); print('cuda', torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')"
```

期望：

```text
torch 2.x.x+cu12x
cuda True
NVIDIA GeForce ...
```

如果 `cuda False`：

- 驱动太旧 → 更新 NVIDIA 驱动。
- 下成了 CPU 包 → 重新下 `..._nvidia.7z`。
- 笔记本双显卡 → 在 NVIDIA 控制面板把 `python.exe` 设为高性能。

---

## 5. 阶段 2 · 下载模型

### 5.1 选择档位

| 显存 | profile | 磁盘 | 内容 |
|---|---|---|---|
| 4GB | `minimal` | ~4GB | SD1.5 + VAE + LCM + 放大 + 2 个 ControlNet |
| 6–8GB | `standard` | ~23GB | minimal + RealVisXL + Animagine + SDXL VAE + LCM-XL + Union |
| ≥8GB 且要视频 | `video` | ~42GB | standard + SVD + Wan2.2 + AnimateDiff |

### 5.2 执行

```powershell
# 先看清单，确认 id 和大小
python .\scripts\download-models.py --list

# 按档位下载
python .\scripts\download-models.py --profile standard --dest "D:\ComfyUI\ComfyUI\models"
```

期望：

- 每个文件输出 `OK <文件名> <大小>`
- 结束输出 `成功 N，跳过 M，失败 0`
- 退出码 0

### 5.3 失败降级顺序

脚本内部已经按 `models.json` 的 sources 顺序尝试。若仍失败：

1. 换 `--source modelscope`
2. 换 `--source cnb`
3. 换 `--source hf`
4. 让用户手动从 <https://modelscope.cn/models> 下载，放到对应目录
5. 记录缺失文件，不要阻塞“第一张图”：先只用已下好的 SD1.5 跑通

### 5.4 校验

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\models\checkpoints" |
  Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

判定：

- `.safetensors` 大小与清单误差 <5% → 通过
- 出现 `.part` → 没下完，重跑
- 只有几 KB → 下到了网页/指针，删掉重下

---

## 6. 阶段 3 · 启动验证

### 6.1 启动

```powershell
cd /d D:\ComfyUI
start-lowvram.bat
```

或直接：

```powershell
D:\ComfyUI\python_embeded\python.exe -s D:\ComfyUI\ComfyUI\main.py --lowvram --use-pytorch-cross-attention --port 8188 --preview-method auto
```

> 这一步会阻塞终端，属于正常。用后台方式启动，或让用户保持窗口打开。

### 6.2 等待并检查

```powershell
# 轮询，最多 120 秒
1..60 | ForEach-Object {
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:8188/system_stats" -TimeoutSec 2
    $r | ConvertTo-Json -Depth 4
    break
  } catch { Start-Sleep -Seconds 2 }
}
```

期望：

- HTTP 200
- JSON 里有 `system.comfyui_version`
- `devices[0].name` 是 NVIDIA 显卡
- `devices[0].vram_total` 与显存相符

### 6.3 检查模型是否被识别

```powershell
Invoke-RestMethod "http://127.0.0.1:8188/models/checkpoints" | ConvertTo-Json
Invoke-RestMethod "http://127.0.0.1:8188/models/loras" | ConvertTo-Json
Invoke-RestMethod "http://127.0.0.1:8188/models/controlnet" | ConvertTo-Json
```

期望：返回的数组里能看到你下载的文件名（不带路径）。

如果为空：

- 检查文件是否在 `ComfyUI\models\checkpoints`。
- 检查扩展名是否 `.safetensors` / `.ckpt`。
- 重启 ComfyUI。
- 检查 `extra_model_paths.yaml` 是否指向了错误目录。

---

## 7. 阶段 4 · 第一张图验收

### 7.1 人工验收（推荐）

1. 浏览器打开 <http://127.0.0.1:8188>。
2. 把 `workflows/sd15-basic.json` 拖进去。
3. `Load Checkpoint` 选已下载的 SD1.5 模型。
4. 点 `Queue`。
5. 等待 5–30 秒。
6. 确认：
   - 页面出现图片
   - 不是全黑/花屏
   - `D:\ComfyUI\ComfyUI\output` 有新文件

### 7.2 程序化验收（可选）

如果用户允许，用 ComfyUI API 提交工作流：

```powershell
# 读取工作流并提交（需要把 JSON 转成 API 格式，或直接用 UI 保存的 API 工作流）
$body = Get-Content ".\workflows\sd15-basic-api.json" -Raw
Invoke-RestMethod -Uri "http://127.0.0.1:8188/prompt" -Method Post -Body $body -ContentType "application/json"
```

> 注意：UI 工作流和 API 工作流格式不同。没有 API 格式时，不要伪造，直接走人工验收。

### 7.3 验收标准

| 项 | 通过标准 |
|---|---|
| 服务 | `/system_stats` 返回 200 |
| 设备 | 识别到 NVIDIA GPU |
| 模型 | `/models/checkpoints` 非空 |
| 出图 | 512×512 在 60 秒内完成（6GB） |
| 输出 | `output` 目录有新 PNG |
| 日志 | 没有 `OutOfMemoryError` / `Traceback` |

全部通过才算完成。任何一项失败，继续排查，不要宣布成功。

---

## 8. 阶段 5 · 低显存故障树

### 8.1 启动失败

```text
服务没起来
├─ 端口被占 → 换 --port 8189
├─ Python 报 ModuleNotFound → 用便携版 python，不要用系统 python
├─ 插件报错 → 加 --disable-all-custom-nodes
├─ CUDA 不可用 → 更新驱动 / 重装 nvidia 包
└─ 路径有中文 → 换纯英文路径
```

### 8.2 显存不足（OOM）

按顺序尝试，每步只改一个变量：

1. 分辨率 1024 → 768 → 512
2. `batch_size` → 1
3. `VAE Decode` → `VAE Decode (Tiled)`，`tile_size` 512 → 256
4. 模型 SDXL → SD1.5
5. 启动参数加 `--lowvram`
6. 还不行加 `--novram`
7. 关闭浏览器视频、游戏、模拟器
8. 虚拟内存调到 32–64GB

### 8.3 模型不显示

```text
模型列表为空
├─ 放错目录 → 放到 models\checkpoints
├─ 没重启 → 重启 ComfyUI
├─ 扩展名不对 → 只认 .safetensors / .ckpt / .pt
├─ 文件损坏 → 检查大小，重下
└─ extra_model_paths.yaml 指错 → 修正 base_path
```

### 8.4 出图异常

| 现象 | 处理 |
|---|---|
| 全黑 | 换 VAE；检查模型是否完整 |
| 花屏 | 模型损坏；换 fp16；降分辨率 |
| 糊 | 步数加到 25–30；换采样器；加放大 |
| 手崩 | 加负面词；用 FaceDetailer/HandDetailer；换模型 |
| 颜色灰 | 换 VAE；CFG 调到 5–7；换 SDXL |

---

## 9. 阶段 6 · 交付报告模板

完成后，按这个格式输出（不要写废话）：

```text
【结论】成功 / 部分成功 / 失败

【环境】
- 系统：
- 显卡 / 显存：
- 驱动：
- 安装路径：
- ComfyUI 版本：

【执行】
1. 安装：命令 + 结果
2. 模型：profile + 成功/失败清单
3. 启动：命令 + 端口
4. 验收：/system_stats 摘要 + 模型列表数量 + 首图耗时

【产物】
- 启动脚本：
- 工作流：
- 输出目录：
- 日志：

【未解决 / 风险】
- ...

【下一步建议】
- ...
```

---

## 10. 禁止事项（硬规则）

1. 不要删除用户已有的 `models`、`output`、`custom_nodes`。
2. 不要覆盖用户的 `extra_model_paths.yaml`，先读再改，改前备份。
3. 不要装来源不明的整合包 / `.exe`。
4. 不要把模型、图片、API Key 上传到任何地方。
5. 不要在没跑验收命令时说“部署完成”。
6. 不要为了“看起来成功”伪造 `/system_stats` 输出。
7. 不要在 4GB 机器上硬上 SDXL 1024。
8. 不要一次装 10 个插件；出问题无法定位。

---

## 11. 快速命令卡

```powershell
# 环境
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
powershell -ExecutionPolicy Bypass -File .\scripts\check-gpu.ps1

# 安装
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -InstallDir "D:\ComfyUI"

# 模型
python .\scripts\download-models.py --list
python .\scripts\download-models.py --profile standard --dest "D:\ComfyUI\ComfyUI\models"

# 校验
D:\ComfyUI\python_embeded\python.exe -c "import torch; print(torch.__version__, torch.cuda.is_available())"
powershell -ExecutionPolicy Bypass -File .\scripts\verify-install.ps1 -InstallDir "D:\ComfyUI"

# 启动
cd /d D:\ComfyUI
start-lowvram.bat

# 验收
Invoke-RestMethod "http://127.0.0.1:8188/system_stats"
Invoke-RestMethod "http://127.0.0.1:8188/models/checkpoints"
```

---

## 12. 版本与兼容性

| 组件 | 本文验证版本 | 说明 |
|---|---|---|
| Windows | 10 / 11 64 位 | 不支持 32 位 |
| ComfyUI | v0.42.1 | 更高版本一般兼容，但插件可能不兼容 |
| Python | 便携版自带（3.12 左右） | 不要混用系统 Python |
| PyTorch | 便携版自带 cu12x | 不要手动升级，除非明确知道在做什么 |
| CUDA 驱动 | ≥ 550 | 更低版本可能不支持自带 torch |

> 如果用户已经装了别的 ComfyUI（秋叶整合包等），不要重复安装。先确认现有实例能否启动、模型目录在哪，再决定是否复用。

---

## 13. 给用户的最后一句

部署完成后，告诉用户：

> 现在可以打开 <http://127.0.0.1:8188>，拖入 `workflows/sd15-basic.json`，选模型，点 Queue。
> 第一次会慢，第二次会快。先跑 512×512，确认稳定后再试 768 或 SDXL。
> 遇到报错，把控制台最后 20 行贴给我。