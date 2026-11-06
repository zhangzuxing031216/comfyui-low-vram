# 03 · 模型：下什么、放哪里、怎么不踩坑

> 新手最容易在“模型”上浪费几十 GB。这一章把模型类型、目录、来源和坑一次讲清。

---

## 1. 模型不是一种东西

ComfyUI 里的“模型”是一组文件，各司其职：

| 类型 | 作用 | 目录 | 典型大小 |
|---|---|---|---|
| Checkpoint / 底模 | 决定画风和基础能力 | `models\checkpoints` | 2–7GB |
| VAE | 把潜空间解码成图片，管颜色 | `models\vae` | 0.3GB |
| LoRA | 小补丁，加画风/角色/加速 | `models\loras` | 0.05–0.6GB |
| ControlNet | 按姿势/线稿/深度控图 | `models\controlnet` | 0.7–2.3GB |
| Upscale | 放大图片 | `models\upscale_models` | 0.06GB |
| Embedding | 负面词/风格嵌入 | `models\embeddings` | 几 MB |
| Face Restore | 修脸 | `models\facerestore_models` | 0.3GB |
| Rembg | 抠图 | `models\rembg` | 0.16GB |
| Inpaint | 去物体/去水印 | `models\inpaint` | 0.1–0.2GB |
| IP-Adapter | 参考图/人脸一致性 | `models\ipadapter` | 0.1GB |
| AnimateDiff | SD1.5 动画运动模块 | `models\animatediff_models` | 1.7GB |
| UNet / Diffusion | 视频/新架构主模型 | `models\unet` | 5GB+ |
| Text Encoder | 文本编码器 | `models\text_encoders` | 0.2–6GB |

**放错目录 = 下拉框里看不到。** 先记目录，再记名字。

---

## 2. 底模怎么选

### 2.1 SD1.5：低显存首选

优点：

- 2GB 左右，加载快
- 4GB 显存能跑
- ControlNet / LoRA 生态最全
- 512×512 速度快

缺点：

- 原生分辨率低，细节不如 SDXL
- 手部/文字容易崩
- 大图需要放大

推荐模型：

| 模型 | 风格 | 大小 | 适合 |
|---|---|---|---|
| `majicmixRealistic_v7` | 写实人像，国人审美 | 2.0GB | 人像、写真 |
| `MeinaMix_V11` | 二次元 | 2.0GB | 动漫角色 |
| `DreamShaper_8` | 通用插画 | 2.0GB | 概念图、插画 |
| `Counterfeit-V3.0` | 二次元 | 4.0GB | 精细动漫 |
| `v1-5-pruned-emaonly` | 官方基础 | 4.3GB | 练 LoRA、对比 |

### 2.2 SDXL：画质更好，但吃显存

优点：

- 原生 1024，细节好
- 写实、动漫都有强模型
- 生态成熟

缺点：

- 6.5GB 左右，6GB 显存要卸载
- 1024 容易 OOM
- 出图慢

推荐模型：

| 模型 | 风格 | 大小 | 6GB 建议 |
|---|---|---|---|
| `RealVisXL_V4.0` | 写实人像 | 6.5GB | 768×768 |
| `Juggernaut-XI` | 写实风景/通用 | 6.6GB | 768×768 |
| `animagine-xl-4.0` | 动漫 | 6.9GB | 768×768 |
| `sd_xl_base_1.0_0.9vae` | 官方基础 | 6.9GB | 768×768 |

### 2.3 SD3.5 / Flux：低显存慎入

| 模型 | 大小 | 6GB 可行性 |
|---|---|---|
| SD3.5 Medium | 4.8GB + 文本编码器 | 勉强，慢 |
| Flux dev fp8 | 11GB | 不推荐 |
| Flux schnell fp8 | 11GB | 不推荐 |

> 网上“6GB 跑 Flux”的教程，多半是极低分辨率 + 长时间等待。新手别从这个开始。

---

## 3. 文件格式：safetensors / ckpt / GGUF

| 格式 | 说明 | 推荐度 |
|---|---|---|
| `.safetensors` | 安全、加载快、不会执行代码 | ★★★★★ |
| `.ckpt` | 老格式，可能含 pickle 代码 | ★★★ 只下可信来源 |
| `.pth` / `.pt` | PyTorch 权重，常见于 ControlNet/放大 | ★★★★ |
| `.gguf` | 量化格式，省显存但需要 GGUF 节点 | ★★★ 低显存视频用 |
| `.bin` | IP-Adapter 等 | ★★★★ |
| `.onnx` | 抠图等 | ★★★★ |

**优先 `.safetensors`。** 来源不明的 `.ckpt` 不要加载。

---

## 4. fp16 / fp8 / GGUF 怎么选

| 精度 | 显存 | 质量 | 适合 |
|---|---|---|---|
| fp32 | 最大 | 最高 | 几乎不用 |
| fp16 | 标准 | 好 | 默认 |
| fp8 | 约一半 | 略降 | 低显存、Flux |
| GGUF Q8 | 约一半 | 接近 fp16 | 低显存视频 |
| GGUF Q4 | 更小 | 有损 | 极限低显存 |

原则：

- SD1.5 / SDXL 优先 fp16。
- 6GB 跑 SDXL 不需要量化，靠 `--lowvram` + 768 就行。
- 视频模型（Wan）优先 GGUF Q8。
- 不要为了“省 1GB”把质量降太多。

---

## 5. VAE：颜色不对先换它

有些底模自带 VAE，有些没有。表现：

- 出图发灰、发绿、过饱和
- 全黑
- 颜色断层

解决：

1. 下载 `vae-ft-mse-840000-ema-pruned.safetensors`（SD1.5）或 `sdxl_vae.safetensors`（SDXL）。
2. 放到 `models\vae`。
3. 在工作流里加 `Load VAE`，接到 `VAE Decode` 的 `vae` 输入。
4. 或者在 `CheckpointLoaderSimple` 后接 `VAE Loader` 覆盖。

> SDXL 模型通常自带 VAE；SD1.5 社区模型经常需要外挂。

---

## 6. LoRA：小文件，大作用

常见用途：

| LoRA | 作用 | 大小 |
|---|---|---|
| LCM-1.5-Lora | SD1.5 4 步加速 | 0.13GB |
| LCM-XL-Lora | SDXL 4–8 步加速 | 0.37GB |
| 角色 LoRA | 固定角色脸/服装 | 0.05–0.2GB |
| 画风 LoRA | 固定画风 | 0.05–0.2GB |
| 细节 LoRA | 加细节/修手 | 0.05–0.2GB |

用法：

1. 放 `models\loras`。
2. 工作流加 `LoraLoader`。
3. `model` / `clip` 从 checkpoint 接进来。
4. 权重先 `0.6–0.8`，别一上来 1.0。

> LoRA 有底模版本：SD1.5 的 LoRA 不能给 SDXL 用。

---

## 7. ControlNet：控图的核心

| 类型 | 作用 | 适合 |
|---|---|---|
| Canny | 边缘 | 轮廓控制 |
| OpenPose | 姿势 | 人物动作 |
| Depth | 深度 | 空间关系 |
| Lineart | 线稿 | 线稿上色 |
| Scribble | 涂鸦 | 草图变成品 |
| Seg | 语义分割 | 布局 |
| Tile | 分块 | 放大/重绘 |
| Inpaint | 局部重绘 | 改图 |

版本匹配：

- SD1.5 → `control_v11p_sd15_*`
- SDXL → `controlnet-*-sdxl` 或 `controlnet-union-sdxl`

6GB 建议：

- 只开 1 个 ControlNet
- 用 fp16 版本（0.67GB）
- 分辨率 512–768
- 权重 0.7–1.0

---

## 8. 放大模型

| 模型 | 适合 | 特点 |
|---|---|---|
| 4x-UltraSharp | 写实 | 锐利，细节强 |
| 4x-AnimeSharp | 动漫 | 线条干净 |
| RealESRGAN_x4plus | 通用/老照片 | 自然，不锐化过度 |
| RealESRGAN_x8 | 极限放大 | 慢，慎用 |

低显存用法：

- 先出 512/768
- 再用 `Upscale Image (using Model)` 放大 2x/4x
- 大图用分块（tile）避免 OOM

---

## 9. 视频模型（6GB 慎入）

| 模型 | 大小 | 用途 | 6GB |
|---|---|---|---|
| SVD XT 1.1 | 4.5GB | 图生视频 | 能跑，慢 |
| AnimateDiff mm_sd_v15_v2 | 1.7GB | SD1.5 动画 | 16 帧可跑 |
| Wan2.2 TI2V 5B GGUF Q8 | 5.0GB | 文/图生视频 | 480p 3 秒 |
| Wan2.2 14B | 33GB | 高质量视频 | 不行 |

视频还需要：

- 文本编码器（Wan 需要 `umt5`）
- VAE（Wan 需要专用 VAE）
- 加速 LoRA（FastWan）
- 补帧模型（RIFE）

**先把图跑通，再碰视频。**

---

## 10. 下载完怎么验证

### 10.1 看大小

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\models\checkpoints" |
  Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

对照 `scripts/models.json` 里的 `size_gb`。

### 10.2 看文件头

```powershell
# safetensors 前 8 字节是长度，后面是 JSON header
Format-Hex -Path "D:\ComfyUI\ComfyUI\models\checkpoints\RealVisXL_V4.0.safetensors" -Count 32
```

正常开头不是 `<html>` 或 `version https://git-lfs...`。

### 10.3 用 Python 校验

```powershell
D:\ComfyUI\python_embeded\python.exe -c "
from safetensors import safe_open
p=r'D:\ComfyUI\ComfyUI\models\checkpoints\RealVisXL_V4.0.safetensors'
with safe_open(p, framework='pt') as f:
    print('keys', len(f.keys()))
"
```

能打开、key 数量正常，就没坏。

### 10.4 常见坏文件

| 现象 | 原因 |
|---|---|
| 只有几 KB | 下到了网页 / LFS 指针 |
| 开头是 `version https://git-lfs` | 下到了 Git LFS 指针，不是文件 |
| 大小对但加载报错 | 下载中断 / 磁盘损坏 |
| `.part` | 没下完 |

---

## 11. 模型放哪里：三种方案

### 方案 A：全部放 ComfyUI 内部（最简单）

```text
D:\ComfyUI\ComfyUI\models\
```

适合：只有一块盘、模型不多。

### 方案 B：模型放外部目录（推荐）

```text
D:\ComfyUI\ComfyUI\models\   ← 只放常用
E:\ComfyUI-models\           ← 大仓库
```

在 `ComfyUI\extra_model_paths.yaml` 写：

```yaml
comfyui_external:
    base_path: E:/ComfyUI-models
    checkpoints: checkpoints
    vae: vae
    loras: loras
    controlnet: controlnet
    upscale_models: upscale_models
```

重启 ComfyUI 生效。

### 方案 C：机械盘归档

不常用的模型放机械盘，用时复制回 SSD。加载速度差 5–10 倍。

---

## 12. 模型许可证（商用必看）

| 模型 | 许可证 | 商用 |
|---|---|---|
| SD1.5 | CreativeML OpenRAIL-M | 有条件允许 |
| SDXL | CreativeML OpenRAIL++-M | 有条件允许 |
| Animagine XL 4.0 | OpenRAIL++ | 有条件允许 |
| RealVisXL | 看模型卡 | 需确认 |
| 社区 LoRA | 各不相同 | 逐个确认 |

**不要假设“网上能下就能商用”。** 商用前看模型卡和许可证原文。

---

## 13. 本章检查清单

- [ ] 知道 checkpoint / VAE / LoRA / ControlNet 的区别
- [ ] 知道每类模型放哪个目录
- [ ] 下载后检查了文件大小
- [ ] 没有把 `.part` 当模型
- [ ] 知道 SD1.5 和 SDXL 的模型不能混用
- [ ] 商用前会看许可证