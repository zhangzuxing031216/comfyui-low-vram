# 04 · 低显存调参：4GB / 6GB / 8GB 的生存指南

> 这一章是整份文档的核心。显存小不是不能跑，是要知道**哪里该降、哪里不能降**。

---

## 1. 先理解显存被谁吃了

跑一张图，显存主要花在：

| 占用 | 说明 | 能不能降 |
|---|---|---|
| 模型权重 | 底模 2–7GB | 换小模型 / 量化 |
| 文本编码器 | CLIP / T5 | 换小编码器 |
| 潜空间 | 分辨率越高越大 | 降分辨率 |
| 注意力 | 分辨率的平方 | 降分辨率 / 换注意力 |
| VAE 解码 | 大图峰值很高 | Tiled VAE |
| ControlNet | 每个 0.7–2.3GB | 少开 / fp16 |
| 放大 | 4x 图非常大 | 分块 |

**分辨率是最敏感的**：512→1024，像素是 4 倍，显存和注意力开销远超 4 倍。

---

## 2. 启动参数：一张表

| 参数 | 作用 | 4GB | 6GB | 8GB |
|---|---|---|---|---|
| `--lowvram` | 模型分层，显存不够换到内存 | 可选 | ✅ | ✅ |
| `--novram` | 更激进，几乎全放内存 | ✅ | OOM 时 | 不建议 |
| `--normalvram` | 默认策略 | ❌ | ❌ | 可试 |
| `--highvram` | 全放显存 | ❌ | ❌ | ❌ |
| `--use-pytorch-cross-attention` | 省显存 + 提速 | ✅ | ✅ | ✅ |
| `--reserve-vram 0.5` | 给系统留显存 | 0.3 | 0.5 | 0.5 |
| `--preview-method auto` | 采样预览 | 可选 | ✅ | ✅ |
| `--disable-smart-memory` | 更激进释放内存 | OOM 时 | OOM 时 | 不建议 |
| `--disable-all-custom-nodes` | 禁用插件 | 排查用 | 排查用 | 排查用 |

### 推荐组合

**4GB**

```bat
python_embeded\python.exe -s ComfyUI\main.py ^
  --novram --use-pytorch-cross-attention --reserve-vram 0.3 --port 8188
```

**6GB**

```bat
python_embeded\python.exe -s ComfyUI\main.py ^
  --lowvram --use-pytorch-cross-attention --port 8188
```

**8GB**

```bat
python_embeded\python.exe -s ComfyUI\main.py ^
  --lowvram --use-pytorch-cross-attention --port 8188
```

> Windows bat 里换行用 `^`，或者写在一行。

---

## 3. 分辨率：最重要的旋钮

| 显存 | SD1.5 | SDXL | 建议 |
|---|---|---|---|
| 4GB | 512×512 | 不要 | 512 出图 + 放大 |
| 6GB | 512–768 | 768×768 | 768 出图 + 放大 |
| 8GB | 768–1024 | 1024×1024 | 1024 可试 |
| 12GB | 1024 | 1024–1536 | 批量 |

### 为什么不要硬上 1024

SDXL 原生 1024 在 6GB 上不是“完全不能跑”，而是：

- 第一次可能成功
- 开 ControlNet / 放大就 OOM
- 速度慢到无法迭代
- 内存占用高，浏览器一开就崩

**正确姿势**：768 出图 → 4x 放大到 3072 → 再缩到 2048。质量比硬上 1024 更稳。

---

## 4. Tiled VAE：大图不 OOM 的关键

### 4.1 什么时候用

- 出图分辨率 ≥ 1024
- 放大到 2x/4x
- VAE Decode 时 OOM
- 出图边缘出现接缝（调 tile 大小）

### 4.2 怎么用

1. 右键空白处 → Add Node → `latent` → `VAE Decode (Tiled)`。
2. 把 `KSampler` 的 `LATENT` 接到 `samples`。
3. 把 `CheckpointLoaderSimple` 的 `VAE` 接到 `vae`。
4. `tile_size`：
   - 6GB：512
   - 4GB：256
   - 8GB：512–768
5. `overlap`：64（默认），接缝明显就加到 128。

### 4.3 代价

- 比普通 VAE Decode 慢 10–30%
- tile 太小会有接缝
- 颜色可能轻微不一致

---

## 5. 量化：什么时候该用

| 场景 | 推荐 | 不推荐 |
|---|---|---|
| SD1.5 / SDXL | fp16 | GGUF Q4 |
| Flux | fp8 | fp16 |
| Wan 视频 | GGUF Q8 | fp16 |
| 极限 4GB | GGUF Q4 | 大模型 fp16 |

原则：**先降分辨率，再考虑量化。** 量化会掉质量，分辨率降太多也掉质量，先试免费的。

---

## 6. 注意力优化

### 6.1 `--use-pytorch-cross-attention`

- 官方支持，稳定
- 省显存
- 大多数机器上更快

### 6.2 SageAttention / FlashAttention

- 更快，但需要额外安装
- 版本/驱动不匹配会报错
- 新手不建议一上来装

### 6.3 xformers

- 老方案
- 新版本 PyTorch 自带 SDPA 后，优势不大
- 装不好会拖慢启动

**结论**：先用 `--use-pytorch-cross-attention`，别折腾。

---

## 7. 内存与虚拟内存

低显存模式下，模型会往内存卸载。16GB 内存跑 SDXL 时：

- 系统占 4–6GB
- ComfyUI 占 6–10GB
- 浏览器占 2–4GB
- 剩余很少 → 开始用虚拟内存 → 变慢/崩

### 优化

1. 关浏览器多余标签页。
2. 关游戏/模拟器/剪映。
3. 虚拟内存 32–64GB。
4. 不要把模型放机械盘（加载慢）。
5. 一次只跑一个任务。

### 看内存

```powershell
Get-CimInstance Win32_OperatingSystem |
  Select-Object @{n='TotalGB';e={[math]::Round($_.TotalVisibleMemorySize/1MB,1)}},
                @{n='FreeGB';e={[math]::Round($_.FreePhysicalMemory/1MB,1)}}
```

---

## 8. 批次与并行

| 设置 | 显存 | 速度 | 建议 |
|---|---|---|---|
| batch_size 1 | 最低 | 单张 | 低显存默认 |
| batch_size 2 | 约 1.5–2x | 略快 | 8GB 可试 |
| batch_size 4 | 高 | 快 | 12GB+ |
| 同时开两个 ComfyUI | 翻倍 | 不推荐 | 除非显存充足 |

低显存不要用 batch 换速度，先保证不 OOM。

---

## 9. 采样器与步数

| 采样器 | 特点 | 低显存 |
|---|---|---|
| Euler | 稳，快 | ✅ |
| Euler a | 更有创意，细节多 | ✅ |
| DPM++ 2M | 质量好 | ✅ |
| DPM++ 2M Karras | 细节好 | ✅ |
| DPM++ SDE Karras | 质量高，慢 | 6GB 可试 |
| LCM | 4–8 步 | ✅ 最快 |

步数：

- SD1.5：20–30
- SDXL：25–35
- LCM：4–8
- 超过 40 步收益很小

---

## 10. CFG

| 模型 | CFG |
|---|---|
| SD1.5 | 6–8 |
| SDXL | 4–6 |
| LCM | 1–2 |
| Turbo | 1–2 |

CFG 太高：过曝、僵硬、色彩脏。
CFG 太低：不听话、模糊。

---

## 11. 低显存工作流模板

### 11.1 4GB：SD1.5 512 快速出图

```text
Load Checkpoint (majicmix / MeinaMix)
  → KSampler (512×512, 20 步, CFG 7, Euler)
  → VAE Decode
  → Save Image
```

加 LCM：

```text
Load Checkpoint
  → LoraLoader (LCM-1.5, 0.8)
  → KSampler (4–6 步, CFG 1.5–2)
```

### 11.2 6GB：SDXL 768 + 放大

```text
Load Checkpoint (RealVisXL)
  → KSampler (768×768, 25 步, CFG 5, dpmpp_2m/karras)
  → VAE Decode (Tiled, tile 512)
  → Upscale Image (4x-UltraSharp)
  → Save Image
```

### 11.3 8GB：SDXL 1024

```text
Load Checkpoint (RealVisXL / Juggernaut)
  → KSampler (1024×1024, 30 步, CFG 5)
  → VAE Decode (Tiled, tile 768)
  → Save Image
```

---

## 12. 性能对比（实测 6GB）

| 配置 | 耗时 |
|---|---|
| SD1.5 512 / 20 步 | 6.7 秒 |
| SD1.5 768 / 20 步 | 15.1 秒 |
| SD1.5 512 / 30 步 | 9.4 秒 |
| SDXL 768 / 25 步 | 40–90 秒 |
| SDXL 768 + 4x 放大 | 3–10 分钟 |
| SD1.5 + LCM 4 步 | 1.5–3 秒 |

> 同一张图重复跑 0.5 秒是缓存，不是真实速度。

---

## 13. 常见误区

### 误区 1：显存小就一定要 `--novram`

错。`--novram` 很慢。6GB 用 `--lowvram` 通常更好。

### 误区 2：开 `--highvram` 会更快

错。显存不够会直接 OOM。

### 误区 3：分辨率越高越好

错。超过模型原生分辨率，收益递减，还容易出双头/重复肢体。

### 误区 4：装更多插件会更快

错。插件增加启动时间和显存占用，很多还会冲突。

### 误区 5：量化一定能救

错。Q4 会明显掉质量，且需要额外节点。

### 误区 6：6GB 能跑 1024 就等于能用

错。“能跑一次”和“能稳定迭代”是两回事。

---

## 14. 调参顺序（照这个来）

```text
1. 先跑 512×512，确认能出图
2. 固定 seed，调 prompt
3. 加到 768，看是否 OOM
4. 加 Tiled VAE
5. 加放大
6. 加 ControlNet（一次一个）
7. 加 LoRA（一次一个）
8. 最后才试 1024 / 视频
```

每次只改一个变量，出问题才知道是谁。

---

## 15. 本章检查清单

- [ ] 知道自己的启动参数
- [ ] 知道 512/768/1024 的取舍
- [ ] 会用 Tiled VAE
- [ ] 虚拟内存 ≥32GB
- [ ] 出图前关掉吃显存的软件
- [ ] 不滥用 `--novram` / `--highvram`
- [ ] 一次只加一个插件/LoRA/ControlNet