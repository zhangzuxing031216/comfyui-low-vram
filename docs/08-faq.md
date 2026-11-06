# 08 · 常见问题（FAQ）

> 按“新手最常问”的顺序排列。答案尽量短，细节看对应章节。

---

## 安装与启动

### Q1：必须用 NVIDIA 显卡吗？

不是必须，但 NVIDIA 最省心。AMD 用 `ComfyUI_windows_portable_amd.7z`，Intel 用 `..._intel.7z`。本文的低显存参数主要针对 N 卡。

### Q2：需要先装 Python 吗？

不需要。便携版自带 Python 和 PyTorch。

### Q3：需要装 Git 吗？

只跑 ComfyUI 不需要。装插件、更新、克隆仓库时需要。

### Q4：装 C 盘可以吗？

可以，但模型很占空间。建议 D/E 盘。

### Q5：路径可以有中文吗？

尽量不要。少数插件对中文路径处理不好。

### Q6：启动要多久？

干净安装 10–30 秒；插件多可能 2–5 分钟。

### Q7：双击 bat 一闪而过怎么办？

在 PowerShell 里运行，看报错：

```powershell
cd /d D:\ComfyUI
.\start-lowvram.bat
```

### Q8：浏览器打不开 8188？

- 服务没起来：看控制台最后一行。
- 端口占用：换 `--port 8189`。
- 防火墙：允许 Python 访问专用网络。

### Q9：能不能用手机访问？

可以，同一局域网访问 `http://电脑IP:8188`，需要加 `--listen 0.0.0.0`。注意安全，不要暴露到公网。

### Q10：能不能同时开两个 ComfyUI？

可以，不同端口 + 不同模型目录。但显存会翻倍，低显存不建议。

---

## 模型

### Q11：模型放哪里？

`D:\ComfyUI\ComfyUI\models\checkpoints`（底模）。

### Q12：为什么模型下拉框是空的？

放错目录 / 没刷新 / 文件坏了。按 `R`，重启，检查扩展名。

### Q13：`.safetensors` 和 `.ckpt` 有什么区别？

`.safetensors` 更安全、加载快；`.ckpt` 可能含可执行代码。优先 `.safetensors`。

### Q14：SD1.5 和 SDXL 的模型能混用吗？

不能。底模、VAE、ControlNet、LoRA 都有版本匹配。

### Q15：一个模型多大？

- SD1.5：2–4GB
- SDXL：6–7GB
- Flux：11GB+
- 视频：5–33GB

### Q16：模型下到几 KB 就停了？

下到了网页或 LFS 指针。用脚本或 ModelScope 重下。

### Q17：模型能删吗？

能。删之前确认没在工作流里用。删完重启。

### Q18：模型能放机械盘吗？

能，但加载慢。常用模型放 SSD，不常用的归档。

### Q19：LoRA 放哪里？

`models\loras`。

### Q20：VAE 放哪里？

`models\vae`。

---

## 显存与性能

### Q21：6GB 能跑 SDXL 吗？

能，768×768 + Tiled VAE + `--lowvram`。1024 容易 OOM。

### Q22：4GB 能跑什么？

SD1.5 512×512、LCM 4 步、轻量 ControlNet。

### Q23：为什么我一跑就 OOM？

按顺序：降分辨率 → batch 1 → Tiled VAE → 换 SD1.5 → `--novram` → 关后台 → 加虚拟内存。

### Q24：`--lowvram` 和 `--novram` 怎么选？

6GB 用 `--lowvram`；4GB 或 OOM 时用 `--novram`。`--novram` 更慢。

### Q25：`--highvram` 能加速吗？

低显存不要开，会直接 OOM。

### Q26：为什么第二次出图快很多？

模型还在显存/内存里，且 ComfyUI 有缓存。

### Q27：为什么同一张图重复跑只要 0.5 秒？

缓存，不是真实速度。

### Q28：怎么让出图更快？

- 降分辨率
- 降步数
- 用 LCM
- 换 SD1.5
- 关后台
- 模型放 SSD

### Q29：笔记本为什么越跑越慢？

散热降频。垫高、清灰、限制功耗、别连续跑几小时。

### Q30：16GB 内存够吗？

SD1.5 够；SDXL 勉强；建议 32GB。

---

## 出图质量

### Q31：出图全黑？

换 VAE、重下模型、恢复默认 steps/cfg。

### Q32：出图发灰？

VAE 不对，换 `vae-ft-mse` 或 `sdxl_vae`。

### Q33：手总是崩？

SD1.5 的极限。加负面词、FaceDetailer、换 SDXL、避开复杂手部。

### Q34：脸不像？

- 换写实模型
- 加 FaceDetailer
- 用 IP-Adapter FaceID
- 提示词写清楚

### Q35：怎么固定一张图？

固定 seed + 模型 + 提示词 + 参数 + LoRA/ControlNet。

### Q36：CFG 多少合适？

SD1.5：6–8；SDXL：4–6；LCM：1–2。

### Q37：步数多少合适？

SD1.5：20–30；SDXL：25–35；LCM：4–8。

### Q38：采样器选哪个？

新手 `euler` / `dpmpp_2m`；想细节 `dpmpp_2m_sde` / `karras`。

### Q39：怎么放大？

4x-UltraSharp（写实）/ 4x-AnimeSharp（动漫）/ RealESRGAN（通用）。低显存用分块。

### Q40：能商用吗？

看模型许可证。SD1.5/SDXL 有条件允许，社区模型各不相同。

---

## 插件

### Q41：要不要装 ComfyUI Manager？

建议装，方便装插件。但它本身也可能带来问题。

### Q42：装多少插件合适？

先 0 个，跑通原生。需要什么装什么，一次一个。

### Q43：插件报 `IMPORT FAILED` 怎么办？

安全模式启动，逐个禁用，找报错插件。

### Q44：插件缺依赖怎么办？

按插件 README 装；用 `python_embeded\python.exe -m pip install`。

### Q45：插件能删吗？

能。移到 `custom_nodes.disabled` 或删除，重启。

---

## 视频

### Q46：6GB 能跑视频吗？

能跑 2–4 秒测试片。AnimateDiff / SVD / Wan 5B GGUF。

### Q47：视频为什么这么慢？

视频是几十帧，每帧都要采样 + 解码，显存和算力需求远高于单图。

### Q48：Wan 和 SVD 怎么选？

- 图生视频：SVD 简单
- 文生视频：Wan 5B GGUF
- SD1.5 动画：AnimateDiff

### Q49：视频能商用吗？

看模型许可证，且注意素材版权、肖像权。

---

## 其他

### Q50：ComfyUI 和 WebUI 哪个好？

ComfyUI 节点式、灵活、适合工作流；WebUI 表单式、上手快。低显存两者差不多，ComfyUI 更省心。

### Q51：要不要用整合包？

新手先用便携版；整合包插件多、启动慢、难排查。

### Q52：怎么更新？

```bat
cd /d D:\ComfyUI
update\update_comfyui.bat
```

更新前备份 `custom_nodes` 和 `user`。

### Q53：怎么备份？

备份 `models`（常用）、`custom_nodes`、`user`、`output`。

### Q54：怎么彻底卸载？

删 `D:\ComfyUI` 整个目录即可，不写注册表。

### Q55：在哪看日志？

启动窗口、浏览器 F12、`output` 目录。

### Q56：出问题怎么问人？

贴：

1. 显卡/显存/内存
2. ComfyUI 版本
3. 完整报错最后 20 行
4. 你做了什么
5. 已经试过什么

### Q57：这份文档能转载吗？

可以，保留出处和许可证。模型和 ComfyUI 的版权归各自作者。

### Q58：还有问题怎么办？

先搜报错原文，再看 `06-troubleshooting.md`，最后提 Issue。