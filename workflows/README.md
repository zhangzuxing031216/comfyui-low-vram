# 工作流说明

这里放的是**最小可用**工作流，只用 ComfyUI 原生节点，不依赖任何插件。

| 文件 | 用途 | 底模 | 分辨率 | 显存 |
|---|---|---|---|---|
| `sd15-basic.json` | SD1.5 文生图 | majicmix / MeinaMix | 512×512 | 4GB+ |
| `sdxl-768-lowvram.json` | SDXL 低显存文生图 | RealVisXL | 768×768 | 6GB+ |

## 怎么用

1. 打开 ComfyUI 网页。
2. 把 `.json` 文件直接拖进画布。
3. 在 `Load Checkpoint` 里选你实际下载的模型。
4. 点 `Queue`（或 `Ctrl + Enter`）。

## 注意

- 工作流里的模型名是示例，必须改成你本地有的文件名。
- 如果提示 `Missing Nodes`，说明你改过节点或用了插件；这两个工作流只用原生节点。
- 想改分辨率：`EmptyLatentImage` 的宽高。
- 想改步数/CFG：`KSampler` 的 `steps` / `cfg`。
- 想固定种子：`KSampler` 的 `control_after_generate` 改 `fixed`。

## 低显存建议

- 4GB：只用 `sd15-basic.json`，512×512。
- 6GB：`sd15-basic.json` 随意；`sdxl-768-lowvram.json` 可跑，慢。
- 8GB：两个都行；SDXL 可试 1024（自己改宽高，注意 OOM）。
- 出图 OOM：降分辨率 → batch 1 → Tiled VAE。

## 想加功能

按顺序加，一次一个：

1. 放大：`Upscale Image (using Model)` + `4x-UltraSharp`
2. 控图：`ControlNet Apply` + `openpose` / `lineart`
3. 修脸：Impact Pack 的 `FaceDetailer`
4. 局部重绘：`MaskEditor` + `VAE Encode (for Inpainting)`

每加一个，先跑通再继续。